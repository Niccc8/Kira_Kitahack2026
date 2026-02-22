import { genkit, z } from 'genkit';
import { googleAI } from '@genkit-ai/google-genai';
import * as admin from 'firebase-admin';
import dotenv from "dotenv";
import path from "path";

dotenv.config({
  path: path.resolve(__dirname, "../../.env")
});

// --- CONFIGURATION ---
// Point to the local emulator so we don't need real credentials
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.GCLOUD_PROJECT = 'demo-wira'; 

admin.initializeApp();
const db = admin.firestore(); // Firestore database instance

// Initialize Genkit
const ai = genkit({
  plugins: [googleAI()],
  model: googleAI.model('gemini-2.5-flash'), // Changed to 1.5 as 2.5 is not standard yet
});

// --- TOOLS DEFINITION ---

// --- TOOL 1: SEARCH MYHIJAU ---
// Example1: where can I get solar panels
// Example2: [attached invoice] provide a green alternative for this
const searchMyHijauTool = ai.defineTool(
  {
    name: 'searchMyHijauDirectory',
    description: 'Use this tool ONLY when the user asks for recommendations on green products, sustainable suppliers, alternatives to high-carbon items, or where to buy eco-friendly assets (e.g., solar panels, composters, EVs).',
    inputSchema: z.object({
      query: z.string().describe("A single keyword to search the directory (e.g., 'solar', 'compost', 'packaging', 'led')"),
    }),
    outputSchema: z.object({ results: z.array(z.any()) }),
  },
  async ({ query }) => {
    console.log(`[TOOL] Searching MyHijau for: ${query}`);
    const snapshot = await db.collection('myhijaudirectory')
      .where('keywords', 'array-contains', query.toLowerCase())
      .limit(5).get();
    return { results: snapshot.docs.map(d => d.data()) };
  }
);

// --- TOOL 2: TAX SIMULATOR ---
// Example1: how much do I need to pay for carbon tax
// Example2: how much do I need to pay carbon tax if it is RM35/tonne
// uses user.totalcarbonemissions --> default to 0 and accumulates each time a new invoice is added
const taxSimulatorTool = ai.defineTool(
  {
    name: 'simulateTaxImpact',
    description: 'Use this tool ONLY when the user asks about how much carbon tax they will have to pay, their tax liability, or mentions a specific carbon tax rate (e.g., "RM 35 per tonne").',
    inputSchema: z.object({
      userId: z.string(),
      proposedTaxRate: z.number().describe("The tax rate per tonne in RM. If not specified by user, default to 30."),
    }),
    outputSchema: z.object({ grossLiability: z.number(), savings: z.number() }),
  },
  async ({ userId, proposedTaxRate }) => {
    console.log(`[TOOL] Simulating Tax for User: ${userId} at Rate: RM${proposedTaxRate}`);
    const userDoc = await db.collection('users').doc(userId).get();
    const data = userDoc.data() || {};
    const gross = (data.totalcarbonemission || 0) * proposedTaxRate;
    const net = Math.max(0, gross - (data.gitaTaxCreditBalance || 0));
    return { grossLiability: gross, savings: gross - net };
  }
);

// --- TOOL 3: INVESTMENT SIMULATOR ---
// Example: what is the payback period if I purchase solar panels?
// Example: is it worth it to invest in solar panels?
export const investmentSimulatorTool = ai.defineTool(
  {
    name: 'simulateInvestment',
    description: 'Calculates ROI and payback period for a green asset investment or purchase',
    inputSchema: z.object({
      assetId: z.string().describe("The ID of the asset. Must be one of: 'solar_rooftop_10kwp', 'hvac_inverter_system', 'led_lighting_retrofit', 'battery_storage_20kwh', 'electric_delivery_van'"),
      monthlyEnergyUsageKwh: z.number().describe("Estimated monthly energy usage in kWh. If unknown, default to 5000."),
    }),
    outputSchema: z.object({
      paybackPeriodYears: z.number(),
      annualSavingsRM: z.number(),
      taxSavingsRM: z.number(),
      lifetimeROI: z.number(),
    }),
  },
  async ({ assetId, monthlyEnergyUsageKwh }) => {
    console.log(`[TOOL] Simulating ROI for: ${assetId}`);
    const assetDoc = await db.collection("greenAssets").doc(assetId).get();
    if (!assetDoc.exists) throw new Error("Asset not found in ROI database.");

    const asset = assetDoc.data();
    const TNB_RATE = 0.50;
    const TAX_RATE = 0.24;

    // Calculate savings based on user's energy usage
    const annualEnergyKwh = monthlyEnergyUsageKwh * 12;
    const energyOffsetKwh = annualEnergyKwh * asset!.annualEnergyOffsetPercent;
    const annualSavingsRM = (energyOffsetKwh * TNB_RATE) - asset!.annualMaintenanceRM;
    
    // GITA tax savings
    const taxSavingsRM = asset!.gitaEligible ? asset!.capexRM * TAX_RATE : 0;
    const effectiveCost = asset!.capexRM - taxSavingsRM;
    const paybackPeriodYears = effectiveCost / annualSavingsRM;
    const totalLifetimeSavings = annualSavingsRM * asset!.lifetimeYears;
    const lifetimeROI = ((totalLifetimeSavings - effectiveCost) / effectiveCost) * 100;
    
    return {
      paybackPeriodYears: Number(paybackPeriodYears.toFixed(2)),
      annualSavingsRM,
      taxSavingsRM,
      lifetimeROI: Number(lifetimeROI.toFixed(1)),
    };
  }
);

// --- TOOL 4: INDUSTRY BENCHMARK ---
// Compares user carbon intensity vs industry average
// Example: how does my carbon footprint compare to other manufacturers
// retrieves all of the user.totalEmissions and find the average then compare the current user to the average and give a response
const industryBenchmarkTool = ai.defineTool(
  {
    name: 'getIndustryBenchmark',
    description: 'Use this tool ONLY when the user asks how they compare to competitors, what the industry average is, or if their carbon emissions are "good" or "bad" relative to others.',
    inputSchema: z.object({ userId: z.string() }),
    outputSchema: z.object({ userIntensity: z.number(), industryAverage: z.number(), performance: z.string() }),
  },
  async ({ userId }) => {
    console.log(`[TOOL] Benchmarking User: ${userId}`);
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();
    if (!userData || !userData.industry) throw new Error("User data incomplete");

    const userIntensity = (userData.totalcarbonemission * 1000) / userData.annualRevenue;
    const statsDoc = await db.collection('industry_stats').doc(userData.industry).get();
    const avgIntensity = statsDoc.exists ? statsDoc.data()?.averageIntensity : 0.0002;

    const isGood = userIntensity < avgIntensity;
    const performance = isGood ? "Better (Lower Carbon)" : "Worse (Higher Carbon)";
    const percentDiff = ((Math.abs(userIntensity - avgIntensity) / avgIntensity) * 100).toFixed(0);

    return { userIntensity, industryAverage: avgIntensity, performance: `${percentDiff}% ${performance} than industry average.` };
  }
);

// --- HELPER: Fetch Receipt Details ---
async function getReceiptContext(userId: string, receiptId: string | undefined): Promise<string> {
  if (!receiptId) return "";
  try {
    // Corrected path: users/{userId}/receipts/{receiptId}
    const doc = await db.collection('users').doc(userId).collection('receipts').doc(receiptId).get();
    if (!doc.exists) return "\n[System] User selected a receipt, but ID was not found.";
    
    const data = doc.data();
    return `
    \n=== SELECTED RECEIPT/INVOICE CONTEXT ===
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

// --- THE AGENT FLOW ---
const wiraBotFlow = ai.defineFlow(
  {
    name: 'wiraBot',
    inputSchema: z.object({ 
      userId: z.string(), 
      message: z.string(),
      receiptId: z.string().optional(), 
    }),
    outputSchema: z.string(),
  },
  async ({ userId, message, receiptId}) => {
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();
    const userProfile = userData ? `Industry: ${userData.industry}, Annual Revenue: RM${userData.annualRevenue}, Total Emissions: ${userData.totalcarbonemission}t.` : "Guest User";
    
    const receiptContext = await getReceiptContext(userId, receiptId);
    console.log(`\n--- Processing Request for ${userId} ---`);

    const { text } = await ai.generate({
      prompt: `
        You are Kira, an AI Carbon Consultant helping Malaysian SMEs.
        
        -- USER PROFILE --
        ${userProfile}
        
        -- ACTIVE CONTEXT --
        ${receiptContext ? `User has attached this specific receipt/invoice to the chat:${receiptContext}` : "No specific receipt attached."}
        
        -- INSTRUCTIONS --
        1. Answer the user's query: "${message}"
        2. If a receipt is attached and the user asks how to reduce it, look at the 'Line Items' array. Extract keywords (like 'electricity', 'fuel', 'packaging') and use the searchMyHijauDirectory tool to find green alternatives.
        3. Be conversational, professional, and helpful. Use RM for currency.
      `,
      tools: [searchMyHijauTool, taxSimulatorTool, investmentSimulatorTool, industryBenchmarkTool], 
    });

    return text;
  }
);

main().catch(console.error);

// --- TEST RUNNER ---
// This part actually executes the code when you run the file
async function main() {
  const userId = 'user123';

  // TEST 1: General Chat - No Tool Usage Chit Chat
  // const response1 = await wiraBotFlow({ userId, message: "Hello, who are you?" });
  // console.log("Response 1:", response1);

  // TEST 2: Tool Usage - calls searchMyHijau tool
  // const response2 = await wiraBotFlow({ userId, message: "I need to buy a solar panel." });
  // console.log("Response 2:", response2);

  // TEST 3: Tool Usage (Tax Calculation)
  // const response3 = await wiraBotFlow({ userId, message: "If the carbon tax is RM 35 per tonne, how much will I pay?" });
  // console.log("Response 3:", response3);
  
  // TEST 4: Investment Simulator
  // console.log("\n--- TEST 4: Investment Simulator ---");
  // const res4 = await wiraBotFlow({ userId, message: "Is it worth investing in solar panels?" });
  // console.log("Response:", res4);

  // TEST 5: Industry Benchmark
  // console.log("\n--- TEST 5: Industry Benchmark ---");
  // const res5 = await wiraBotFlow({ userId, message: "How does my carbon footprint compare to other manufacturers?" });
  // console.log("Response:", res5);

  console.log("\n--- TEST 6: Invoice Context ---");
  // User selects the invoice and asks for help
  const res6 = await wiraBotFlow({ 
      userId, 
      message: "How can I reduce the carbon from this bill?", 
      invoiceId: 'invoice_abc' // <--- Simulating dropdown selection
  });
  console.log("Response:", res6);
}

//////////////// main().catch(console.error); /////////////////////

// --- THE CLOUD FUNCTION ENDPOINT ---
export const wiraChat = onRequest({ cors: true }, async (req, res) => {
  // Ensure we only accept POST requests
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  try {
    // Extract payload from Flutter frontend
    const { userId, message, receiptId } = req.body;

    if (!userId || !message) {
      res.status(400).json({ error: "Missing required fields: userId and message" });
      return;
    }

    // Execute the Genkit flow
    const reply = await wiraBotFlow({ userId, message, receiptId });
    
    // Send response back to Flutter
    res.status(200).json({ reply });
  } catch (error: any) {
    console.error("Agent execution error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});