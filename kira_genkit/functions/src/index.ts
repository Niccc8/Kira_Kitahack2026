import 'dotenv/config'; // additional installation
import {genkit, z} from "genkit";
import { googleAI } from '@genkit-ai/google-genai';
import path from "path";
import { readFile } from 'node:fs/promises'; 
import { onCallGenkit } from 'firebase-functions/https';
import { defineSecret } from 'firebase-functions/params';
const googleAIapiKey = defineSecret("GEMINI_API_KEY");


// initialise ai 
const ai = genkit({
    plugins: [
        googleAI({ apiKey: process.env.GOOGLE_GENAI_API_KEY })
    ],
});

// define item schema
const ItemSchema = ai.defineSchema(
    'ItemSchema',
    z.object({
        // think about what attributes does an ItemSchema have, how are each described
        name: z.string().describe("The name of for this line item (eg: petrol, solar panel, diesal, biodegradable container)."),
        supplier: z.string().describe("The supplier of this invoice."),
        quantity: z.number().describe("The amount purchased for this item."),
        unit: z.string().describe("The unit (eg: single, kg, litres) purchased for this line item."),
        price: z.number().describe("The total price for this line item."),
        currency: z.string().default("MYR"),
        isGitaEligible: z.boolean().describe("Whether this item qualifies for GITA (Green Investment Tax Incentive)"),
        dateOfPurchase: z.string().describe("The date of this invoice issued in YYYY-MM-DD format.")
    })
);

// define array of items as a single invoie can have multiple item
const InvoiceResponseSchema = z.object({
    items: z.array(ItemSchema),
    totalAmount: z.number(),
    invoiceNumber: z.string(),
    dateOfPurchase: z.string().describe("The date of this invoice issued in YYYY-MM-DD format."),
})

// define gitaEntry schema
const GITAEntrySchema = ai.defineSchema(
    'GITAEntrySchema',
    z.object({
        tier: z.number().describe("The tier of this GITA entry if eligible for Green Investment Tax Allowance (GITA) Malaysia."),
        sector: z.string().describe("The sector (eg: energy efficiency, renewable energy system, waste, water) of this GITA entry."),
        technology: z.string().describe("The technology (eg: Transformer, Energy Efficient Appliances, Chiller, etc) of this GITA entry."),
        asset: z.string().describe("The asset (eg: Transformer, Thermal Energy Storage/Collector, Variable Air Volume) of this GITA entry."),
        gitaAllowance: z.number().describe("Final tax eligble for exemption based on GITA asset tier (tier 1 eligible for 100%, tier 2 eligible for 60%).")
    })
);


// define carbonEntry schema
// scope 1: 𝐶𝑂2𝑒 𝑒𝑚𝑖𝑠𝑠𝑖𝑜𝑛𝑠 = ∑𝐴𝑐𝑡𝑖𝑣𝑖𝑡𝑦 𝐷𝑎𝑡𝑎 × 𝐸𝑚𝑖𝑠𝑠𝑖𝑜𝑛 𝐹𝑎𝑐𝑡𝑜𝑟 × 𝐺𝑊P, 
// scope 2: 𝐶𝑂2𝑒 𝑒𝑚𝑖𝑠𝑠𝑖𝑜𝑛𝑠 = 𝐸𝑙𝑒𝑐𝑡𝑟𝑖𝑐𝑖𝑡𝑦 𝑝𝑢𝑟𝑐ℎ𝑎𝑠𝑒𝑑 × 𝐺𝐸F
const CarbonEntrySchema = ai.defineSchema(
    'CarbonEntrySchema',
    z.object({
        scope: z.number().describe("Scope (eg: 1,2,3) according to Greenhouse Gas Protocol (GHG) of this carbon entry."),
        activityData: z.number().describe("The activity data of carbon emission of this carbon entry."),
        emissionFactor: z.number().describe("The activity data emission factor of carbon emission of this carbon entry if this entry is of scope 1."),
        gwp: z.number().describe("The Grid Emission Factor (GEP) of this carbon entry if this entry is of scope 2 (electricity)."),
        gef: z.number().describe("The activity data of carbon emission of this carbon entry."),
        co2eEmission: z.number().describe("The co2eEmission calculated using calculateScope1 or calculateScope2 for this carbon entry based on the entry respective scope."),
    })
);

// define flow for extractInvoice()
// output an array on item since a single  invoice can have multiple items
export const extractInvoiceFlow = ai.defineFlow(
    {
        name: 'extractInvoiceFlow', 
        inputSchema: z.object({
            file: z.string().describe("URL or local path to the invoice file"),
        }),
        outputSchema: InvoiceResponseSchema 
    },
    async (input) => {
        const { dataUrl } = await ai.run('load-invoice-file', async () => {
            const filePath = path.resolve(input.file);
            const fileExtension = path.extname(filePath).toLowerCase();
            
            let mimeType = fileExtension === '.pdf' ? 'application/pdf' : `image/${fileExtension.replace('.', '')}`;
            const b64Data = await readFile(filePath, { encoding: 'base64' });
            return { dataUrl: `data:${mimeType};base64,${b64Data}` };
        });

        const { output } = await ai.generate({
            model: googleAI.model('gemini-2.5-flash'),
            prompt: [
                { media: { url: dataUrl } },
                { text: "Extract all line items and total amounts from this invoice. Identify if assets are eligible for Green Investment Tax Incentive (GITA)." },
            ],
            output: {
                schema: InvoiceResponseSchema,
            }
        });

        // error handling
        if (!output) {
            throw new Error('Extraction failed.');
        }

        return output;
    }
);
export const extractInvoice = onCallGenkit(
    {
        secrets: [googleAIapiKey],
    },
    extractInvoiceFlow
);

// define flow for categoriseItems()
export const categoriseItemsFlow = ai.defineFlow(
    {
        name: 'categoriseItemsFlow', 
        inputSchema: InvoiceResponseSchema,
        outputSchema: z.object({
            gitaEntries: z.array(GITAEntrySchema),
            carbonEntries: z.array(CarbonEntrySchema)
        }) 
    },
    async (input) => {

        const gitaEntries = [];
        const carbonEntries = [];

        // map each ItemSchema in InvoiceResponseSchema 
        for (const item of input.items){
            // all ItemSchema are CarbonEntrySchema
            const carbonEntry = await ai.run(`carbon-${item.name}`, async () => {
                return await convertToCarbonEntryFlow(item);
            });
            carbonEntries.push(carbonEntry);

            // only ItemSchema with isGitaEligible are GITAEntrySchema
            if (item.isGitaEligible) {
                const gitaEntry = await ai.run(`gita-${item.name}`, async () => {
                    return await convertToGitaEntryFlow(item);
                });
                gitaEntries.push(gitaEntry);
            }
        }

        // error handling
        if (!gitaEntries && !carbonEntries) {
            throw new Error('Categorisation failed.');
        }

        return { gitaEntries, carbonEntries };
    }
);
export const categoriseItem = onCallGenkit(
    {
        secrets: [googleAIapiKey],
    },
    categoriseItemsFlow
);

// define flow for convertToCarbonEntryFlow()
export const convertToCarbonEntryFlow = ai.defineFlow(
    {
        name: 'convertToCarbonEntryFlow', 
        inputSchema: ItemSchema,
        outputSchema: CarbonEntrySchema, 
    },
    async (item) => {
        const { output } = await ai.generate({
            model: googleAI.model('gemini-2.5-flash'),
            system: `You are a GHG Protocol Auditor for Malaysia in the year 2026.
            Greenhouse gas (GHG) emmsiion are grouped into 3 categories:
            - Scope 1 (Direct emissions): from fuel you burn in your business operations (e.g. diesel for trucks, natural gas for boilers)
            - Scope 2 (Indirect emissions): from the electricity you purchase and use
            - Scope 3 ():
            CO2 emision are calculated based on scope:
            - Scope 1: 𝐶𝑂2𝑒 𝑒𝑚𝑖𝑠𝑠𝑖𝑜𝑛𝑠 = ∑𝐴𝑐𝑡𝑖𝑣𝑖𝑡𝑦 𝐷𝑎𝑡𝑎 × 𝐸𝑚𝑖𝑠𝑠𝑖𝑜𝑛 𝐹𝑎𝑐𝑡𝑜𝑟 × 𝐺𝑊P
            - Scope 2: 𝐶𝑂2𝑒 𝑒𝑚𝑖𝑠𝑠𝑖𝑜𝑛𝑠 = 𝐸𝑙𝑒𝑐𝑡𝑟𝑖𝑐𝑖𝑡𝑦 𝑝𝑢𝑟𝑐ℎ𝑎𝑠𝑒𝑑 × 𝐺𝐸F
            - Scope 3: 
            Regarding scope 2 for electricity consumption, in Malaysia, purchased electricity comes from 3 main electricity grid with their respective emission factor:
            - Peninsular Malaysia supplied by Tenaga Nasional Bhd (TNB): 0.774
             (Kulim Hi-Tech Park is a special case and has its own provider – N.U.R Power Sdn. Bhd. with its own GEF.): 0.540
            - Sabah supplied by Sabah Electricity Sdn. Bhd. (SESB): 0.525
            - Sarawak supplied by Sarawak Energy Bhd: 0.199

            Always return activityData (electricity purchase is an activityData). For scope 1, return emission factor and GWP. For scope 2, return gef`,
            prompt: `Convert this invoice item into a CarbonEntry: ${JSON.stringify(item)}`,
            output: {
                schema: CarbonEntrySchema,
            }
        });

        // error handling
        if (!output) {
            throw new Error("Conversion to carbon entry failed.")
        }

        return output;
    }
);

// define flow for convertToGitaEntryFlow()
export const convertToGitaEntryFlow = ai.defineFlow(
    {
        name: 'convertToGitaEntryFlow', 
        inputSchema: ItemSchema,
        outputSchema: GITAEntrySchema,
    },
    async (item) => {
        const { output } = await ai.generate({
            model: googleAI.model('gemini-2.5-flash'),
            system: `You are a Malaysian Green Tax Consultant
            Categorize the GITA asset's tier based on Malaysian Green Tech & CLimate Change Corporation (MyHIJAU):
            - Tier 1: sectors involving transportation, green building and renewable energy
            - Tier 2: sectors involving energy efficiency, renewable energy system, waste and water

            Categorize the GITA asset's sector, technology and asset based on Malaysian Green Tech & CLimate Change Corporation (MyHIJAU):
            - Tier 1:
                a) Transportation
                    i) Electric Vechicles
                        - Electric Motorcycle/Scooter
                        - Electric Bus
                        - Electric MPV Panel Van
                        - Electric Movers/Terminal Tractors
                        - Electric Forklift
                        - Light & Heavy-Duty Truck/Lorry
                    i) EV Infractructure
                        - Electric Vehicle Charging System
                        - Battery Swapping
                b) Green Buidling
                    i) Green Building
                        - Based on Green Cost Certificate issued by Green Building Certification Body
                c) Renewable Energy
                    i) Energy Storage
                        - Battery Energy Storage System (BESS)
            - Tier 2:
                a) Energy Efficiency
                    i) Transformer 
                        - Transformer
                    ii) Energy Efficient Appliances
                        - Thermal Energy Storage/Collector
                        - Variable Air Volume (VAV)
                        - Variable Refrigerant Volume (VRV)
                    iii) Chiller 
                        - Chiller
                    iv) Heat Operated Air Conditioners
                        - Absorption and Adsorption Air Conditioner
                    v) Cooling Tower 
                        - Cooling Tower
                    vi) Air Compressor 
                        - Air Compressor
                    vii) Air Filtration system 
                        - Industrial Air Filtration system with energy-efficient motors
                    vii) Heat Recovery 
                        - Heat Recovery System
                    ix) Boiler 
                        - Hot Water and Steam Boiler
                    x) Water Heater 
                        - Industrial Water Heater
                b) Renewable Energy System
                    i) RE Project for own consumption
                        - Solar
                        - Biomass
                        - Biogas
                        - Mini Hydro
                        - Geothermal
                        - Wind Energy
                c) Waste 
                    i) Waste Composter 
                        - Composter
                    i) Waste Recycling
                        - Waste Recycling System
                d) Water
                    i) Wastewater Recycling 
                        - Wastewater Recycling System
                    i) Rainwater Harvesting
                        - Rainwater Harvesting System

            When calculating GITA allowance, take the GITA asset's tier into consideration:
            - Tier 1: percentage of GITA is 100%
            - Tier 2: percentage of GITA is 60%
            Incentive period for GITA involves qualifying capital expenditure incurred starting from 1 January 2024 until 31 Decmber 2026.
            Tax allowance is calculated as GITA = GITA asset worth × tier percentage
            Always return tax allowance (ITA) in Malaysian Riggit Currency (RM).
            `,
            prompt: `Convert this eligible green itme into a GITAENtry: ${JSON.stringify(item)}`,
            output: {
                schema: GITAEntrySchema,
            }
        });

        // error handling
        if (!output) {
            throw new Error("Conversion to GITA entry failed.")
        }
        
        return output;
    }
);

// QUICK RUN COMMANDS:
// cd kira_genkit/functions
// npx genkit start -- npx tsx --watch src/index.ts