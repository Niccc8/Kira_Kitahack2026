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

const searchMyHijauTool = ai.defineTool(
  {
    name: 'searchMyHijauDirectory',
    description: 'Finds government-approved green assets. Use for queries about products/suppliers.',
    inputSchema: z.object({
      query: z.string(),
    }),
    outputSchema: z.object({
      results: z.array(z.any()),
    }),
  },
  async ({ query }) => {
    console.log(`[TOOL] Searching MyHijau for: ${query}`);
    const snapshot = await db.collection('myhijau_assets')
      .where('keywords', 'array-contains', query.toLowerCase())
      .limit(5)
      .get();
    return { results: snapshot.docs.map(d => d.data()) };
  }
);

const taxSimulatorTool = ai.defineTool(
  {
    name: 'simulateTaxImpact',
    description: 'Calculates carbon tax liability. Use when user asks about tax cost or savings.',
    inputSchema: z.object({
      userId: z.string(),
      proposedTaxRate: z.number(),
    }),
    outputSchema: z.object({
      grossLiability: z.number(),
      savings: z.number(),
    }),
  },
  async ({ userId, proposedTaxRate }) => {
    console.log(`[TOOL] Simulating Tax for User: ${userId} at Rate: ${proposedTaxRate}`);
    const userDoc = await db.collection('users').doc(userId).get();
    const data = userDoc.data() || {};
    const gross = (data.totalEmissions || 0) * proposedTaxRate;
    const net = Math.max(0, gross - (data.gitaTaxCreditBalance || 0));
    return { grossLiability: gross, savings: gross - net };
  }
);

// --- THE AGENT FLOW ---

const wiraBotFlow = ai.defineFlow(
  {
    name: 'wiraBot',
    inputSchema: z.object({ userId: z.string(), message: z.string() }),
    outputSchema: z.string(),
  },
  async ({ userId, message }) => {
    // Fetch user context
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();
    const context = userData 
      ? `Industry: ${userData.industry}, Annual Emissions: ${userData.totalEmissions}t.` 
      : "Guest User";

    console.log(`\n--- Processing Request for ${userId} ---`);
    console.log(`Context: ${context}`);

    const { text } = await ai.generate({
      prompt: `
        You are Wira, an AI Carbon Consultant.
        User Context: ${context}
        Goal: Minimize carbon tax liability.
        User Query: ${message}
      `,
      tools: [searchMyHijauTool, taxSimulatorTool], 
    });

    return text;
  }
);

// --- TEST RUNNER ---
// This part actually executes the code when you run the file
async function main() {
  const userId = 'user123';

  // TEST 1: General Chat
  // const response1 = await wiraBotFlow({ userId, message: "Hello, who are you?" });
  // console.log("Response 1:", response1);

  // TEST 2: Tool Usage (Database Search)
//   const response2 = await wiraBotFlow({ userId, message: "I need to buy a solar panel." });
//   console.log("Response 2:", response2);

  // TEST 3: Tool Usage (Tax Calculation)
  const response3 = await wiraBotFlow({ userId, message: "If the carbon tax is RM 35 per tonne, how much will I pay?" });
  console.log("Response 3:", response3);
}

main().catch(console.error);