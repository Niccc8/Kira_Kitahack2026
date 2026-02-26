/**
 * Chatbot Agent Flow — "Kira" AI Carbon Consultant
 *
 * Integrated version of the user's chatbot logic with lazy initialization
 * and safety checks for robust production use.
 */

import { z } from 'zod';
import * as admin from 'firebase-admin';

// --- Firebase Admin (shared singleton) ---
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();

// --- Lazy Genkit instance ---
let _ai: any = null;

function getAI() {
    if (_ai) return _ai;

    const { genkit } = require('genkit');
    const { googleAI } = require('@genkit-ai/googleai');

    _ai = genkit({
        plugins: [
            googleAI({
                apiKey: process.env.GOOGLE_GENAI_API_KEY,
            }),
        ],
        model: googleAI.model('gemini-2.5-flash'),
    });

    registerTools(_ai);
    return _ai;
}

// --- Tool references ---
let _searchMyHijauTool: any;
let _taxSimulatorTool: any;
let _investmentSimulatorTool: any;
let _industryBenchmarkTool: any;

function registerTools(ai: any) {
    // ═══ TOOL 1: MyHijau Green Product Search ═══
    _searchMyHijauTool = ai.defineTool(
        {
            name: 'searchMyHijauDirectory',
            description: 'Use this tool ONLY when the user asks for recommendations on green products, sustainable suppliers, alternatives to high-carbon items, or where to buy eco-friendly assets.',
            inputSchema: z.object({
                query: z.string().describe("A single keyword to search (e.g., 'solar', 'led')"),
            }),
            outputSchema: z.object({ results: z.array(z.any()) }),
        },
        async ({ query }: { query: string }) => {
            console.log(`[TOOL] Searching MyHijau for: ${query}`);
            const snapshot = await db.collection('myhijaudirectory')
                .where('keywords', 'array-contains', query.toLowerCase())
                .limit(5).get();
            return { results: snapshot.docs.map(d => d.data()) };
        }
    );

    // ═══ TOOL 2: Carbon Tax Simulator ═══
    _taxSimulatorTool = ai.defineTool(
        {
            name: 'simulateTaxImpact',
            description: 'Use this tool ONLY when the user asks about how much carbon tax they will have to pay, their tax liability, or mentions a specific carbon tax rate.',
            inputSchema: z.object({
                userId: z.string(),
                proposedTaxRate: z.number().describe("Tax rate per tonne in RM. Default to 30 if not specified."),
            }),
            outputSchema: z.object({ grossLiability: z.number(), savings: z.number() }),
        },
        async ({ userId, proposedTaxRate }: { userId: string; proposedTaxRate: number }) => {
            console.log(`[TOOL] Simulating Tax for User: ${userId} at Rate: RM${proposedTaxRate}`);
            const userDoc = await db.collection('users').doc(userId).get();
            const data = userDoc.data() || {};
            const emissions = data.totalcarbonemission || data.totalEmissions || 0;
            const gross = emissions * proposedTaxRate;
            const net = Math.max(0, gross - (data.gitaTaxCreditBalance || 0));
            return { grossLiability: gross, savings: gross - net };
        }
    );

    // ═══ TOOL 3: Green Investment ROI Simulator ═══
    _investmentSimulatorTool = ai.defineTool(
        {
            name: 'simulateInvestment',
            description: 'Calculates ROI and payback period for a green asset investment or purchase',
            inputSchema: z.object({
                assetId: z.string().describe("The ID of the asset. (e.g. 'solar_rooftop_10kwp')"),
                monthlyEnergyUsageKwh: z.number().describe("Estimated monthly energy usage in kWh. Default 5000."),
            }),
            outputSchema: z.object({
                paybackPeriodYears: z.number(),
                annualSavingsRM: z.number(),
                taxSavingsRM: z.number(),
                lifetimeROI: z.number(),
            }),
        },
        async ({ assetId, monthlyEnergyUsageKwh }: { assetId: string; monthlyEnergyUsageKwh: number }) => {
            console.log(`[TOOL] Simulating ROI for: ${assetId}`);
            const assetDoc = await db.collection("greenAssets").doc(assetId).get();
            if (!assetDoc.exists) throw new Error("Asset not found in ROI database.");

            const asset = assetDoc.data()!;
            const TNB_RATE = 0.50;
            const TAX_RATE = 0.24;

            const annualEnergyKwh = (monthlyEnergyUsageKwh || 5000) * 12;
            const energyOffsetKwh = annualEnergyKwh * (asset.annualEnergyOffsetPercent || 0);
            const annualSavingsRM = (energyOffsetKwh * TNB_RATE) - (asset.annualMaintenanceRM || 0);
            
            const taxSavingsRM = asset.gitaEligible ? (asset.capexRM || 0) * TAX_RATE : 0;
            const effectiveCost = (asset.capexRM || 0) - taxSavingsRM;
            
            // Safety check for division by zero
            const paybackPeriodYears = annualSavingsRM > 0 ? effectiveCost / annualSavingsRM : 99;
            const totalLifetimeSavings = annualSavingsRM * (asset.lifetimeYears || 1);
            const lifetimeROI = effectiveCost > 0 ? ((totalLifetimeSavings - effectiveCost) / effectiveCost) * 100 : 0;
            
            return {
                paybackPeriodYears: Number(paybackPeriodYears.toFixed(2)),
                annualSavingsRM,
                taxSavingsRM,
                lifetimeROI: Number(lifetimeROI.toFixed(1)),
            };
        }
    );

    // ═══ TOOL 4: Industry Benchmark ═══
    _industryBenchmarkTool = ai.defineTool(
        {
            name: 'getIndustryBenchmark',
            description: 'Compares user carbon intensity vs industry average. Use when user asks how they compare to competitors.',
            inputSchema: z.object({userId: z.string()}),
            outputSchema: z.object({ userIntensity: z.number(), industryAverage: z.number(), performance: z.string() }),
        },
        async ({ userId }: { userId: string }) => {
            console.log(`[TOOL] Benchmarking User: ${userId}`);
            const userDoc = await db.collection('users').doc(userId).get();
            const userData = userDoc.data();
            if (!userData || !userData.industry) throw new Error("User data incomplete");

            const emissions = userData.totalcarbonemission || userData.totalEmissions || 0;
            const userIntensity = (emissions * 1000) / (userData.annualRevenue || 1);
            const statsDoc = await db.collection('industry_stats').doc(userData.industry).get();
            const avgIntensity = statsDoc.exists ? statsDoc.data()?.averageIntensity : 0.0002;

            const isGood = userIntensity < avgIntensity;
            const performance = isGood ? "Better (Lower Carbon)" : "Worse (Higher Carbon)";
            const percentDiff = avgIntensity > 0 ? ((Math.abs(userIntensity - avgIntensity) / avgIntensity) * 100).toFixed(0) : "0";

            return { userIntensity, industryAverage: avgIntensity, performance: `${percentDiff}% ${performance} than industry average.` };
        }
    );
}

// --- HELPER: Fetch Receipt Context ---
async function getReceiptContext(userId: string, receiptId: string | undefined): Promise<string> {
    if (!receiptId) return "";
    try {
        const doc = await db.collection('users').doc(userId).collection('receipts').doc(receiptId).get();
        if (!doc.exists) return "\n[System] User selected a receipt, but ID was not found.";
        
        const data = doc.data();
        return `
=== SELECTED RECEIPT/INVOICE CONTEXT ===
Receipt ID: ${receiptId}
Vendor: ${data?.vendor || "Unknown"}
Date: ${data?.date || "N/A"}
Line Items: ${JSON.stringify(data?.lineItems || [])}
================================
`;
    } catch (error) {
        console.error("Error fetching receipt:", error);
        return "\n[System] Error retrieving receipt details.";
    }
}

// --- MAIN AGENT FLOW ---
export async function wiraBotFlow(input: {
    userId: string;
    message: string;
    receiptId?: string;
}): Promise<string> {
    const ai = getAI();
    const { userId, message, receiptId } = input;

    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();
    
    // FIX 1: Put the userId back into the profile string so the LLM knows it!
    const userProfile = userData 
        ? `User ID: ${userId}, Industry: ${userData.industry}, Annual Revenue: RM${userData.annualRevenue}, Total Emissions: ${userData.totalcarbonemission || userData.totalEmissions || 0}t.` 
        : `User ID: ${userId} (Guest User)`;
    
    const receiptContext = await getReceiptContext(userId, receiptId);
    console.log(`\n--- [wiraBot] Processing Request for ${userId} ---`);

    const { text } = await ai.generate({
        // FIX 2: Explicitly tell the LLM to use the User ID for tools
        system: `You are Kira, an AI Carbon Consultant helping Malaysian SMEs.
         
        -- USER PROFILE --
        ${userProfile}
         
        -- ACTIVE CONTEXT --
        ${receiptContext ? `User has attached this specific receipt/invoice to the chat:${receiptContext}` : "No specific receipt attached."}
         
        -- INSTRUCTIONS --
        1. Answer the user's query directly.
        2. CRITICAL: If you need to use the simulateTaxImpact or getIndustryBenchmark tools, strictly use the User ID provided in the profile above.
        3. If a receipt is attached and the user asks how to reduce it, look at the 'Line Items' array. Extract a SINGLE keyword (like 'electricity', 'fuel', 'packaging') and use the searchMyHijauDirectory tool.
        4. Be conversational, professional, and helpful. Use RM for currency.`,
        
        prompt: message, // Keep the user's actual message clean
        tools: [_searchMyHijauTool, _taxSimulatorTool, _investmentSimulatorTool, _industryBenchmarkTool],
    });

    return text;
}