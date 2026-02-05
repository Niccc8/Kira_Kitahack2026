// z is the Zod schema validation library
import { genkit, z } from 'genkit';  
// Google Gemini 1.5 Flash model plugin
import { googleAI } from '@genkit-ai/google-genai';
//creates a firebase callable HTTPS function, for frontend calls
import { onCallGenkit } from 'firebase-functions/https';
import { logger } from 'genkit/logging';
// Firebase Admin SDK for Firestore access, read/write from server side
import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';

// 1. Initialize Firebase Admin (for Database Access)
admin.initializeApp();
const db = admin.firestore(); // Firestore database instance

// 2. Initialize Genkit AI runtime with Gemini 1.5 Flash  
const ai = genkit({
  plugins: [googleAI()], 
  model: googleAI.model('gemini-2.5-flash'),
});


// Helper to format user data for the prompt
function userContextToString(data: any): string {
  if (!data) return "User is a guest.";
  return `Industry: ${data.industry}, Annual Rev: RM${data.annualRevenue}, Last Month Emissions: ${data.lastMonthEmissions}t.`;
}

// --- EXPORT FOR FIREBASE FUNCTIONS ---
// This creates the HTTPS callable endpoint "wiraBot"
// Wraps the AI flow
// Exposes it as a Firebase HTTPS callable endpoint
// Frontend can call:
// httpsCallable('wiraBot')
export const wiraBot = onCallGenkit({
  secrets: [], // Add API keys here if needed (e.g. Google Maps key)
}, wiraBotFlow);

// --- HELPER SCHEMAS ---

// Common schemas to keep code clean
// for user profile data validation, future checking
const UserProfileSchema = z.object({
  userId: z.string(),
  industry: z.string(),
  annualRevenue: z.number(),
  currentEmissions: z.number(), // tonnes CO2e
  gitaCredits: z.number(), // RM
});

// --- TOOL 1: THE GREEN VENDOR SCOUT (RAG/Vector Search) ---
// Note: This requires a Firestore collection 'myhijau_assets' with vector embeddings
export const searchMyHijauTool = ai.defineTool(
  {
    name: 'searchMyHijauDirectory',
    description: 'Finds government-approved (MyHijau) green assets that qualify for tax deductions.',
    inputSchema: z.object({
      query: z.string().describe('The product to find (e.g., "LED lights", "Solar Panel", "Chiller")'),
      location: z.string().optional().describe('Preferred location (e.g., "Selangor")'),
    }),
    outputSchema: z.object({
      results: z.array(z.object({
        name: z.string(),
        supplier: z.string(),
        expiryDate: z.string(),
        gitaEligible: z.boolean(),
      })),
    }),
  },
  async ({ query, location }) => {
    // In a real app, this uses ai.retrieve() with a Vector Index.
    // For this MVP code, we simulate a keyword query.
    const snapshot = await db.collection('myhijau_assets')
      .where('keywords', 'array-contains', query.toLowerCase())
      .limit(5)
      .get();

    if (snapshot.empty) {
      return { results: [] };
    }

    const results = snapshot.docs.map(doc => ({
      name: doc.data().name,
      supplier: doc.data().supplier,
      expiryDate: doc.data().expiryDate, // e.g., "2026-12-31"
      gitaEligible: true, // Simplified for MVP
    }));

    return { results };
  }
);

// --- TOOL 2: COMPETITOR BENCHMARKER ---
// export const industryBenchmarkTool = ai.defineTool(
//   {
//     name: 'getIndustryBenchmark',
//     description: 'Compares the user\'s carbon intensity against industry averages.',
//     inputSchema: z.object({
//       industry: z.string().describe('The industry sector (e.g., "Manufacturing", "Logistics")'),
//       userEmissionIntensity: z.number().describe('User emissions per RM revenue (kgCO2e/RM)'),
//     }),
//     outputSchema: z.object({
//       industryAverage: z.number(),
//       comparison: z.string(),
//       status: z.enum(['Excellent', 'Average', 'Critical']),
//     }),
//   },
//   async ({ industry, userEmissionIntensity }) => {
//     // In production, this queries BigQuery. Here we fetch from a stats doc.
//     const statsDoc = await db.collection('industry_stats').doc(industry.toLowerCase()).get();
    
//     // Default fallback if no data
//     const average = statsDoc.exists ? statsDoc.data()?.averageIntensity : 20.5; 

//     let status: 'Excellent' | 'Average' | 'Critical' = 'Average';
//     if (userEmissionIntensity < average * 0.8) status = 'Excellent';
//     if (userEmissionIntensity > average * 1.2) status = 'Critical';

//     return {
//       industryAverage: average,
//       comparison: `${((userEmissionIntensity / average) * 100).toFixed(0)}%`,
//       status,
//     };
//   }
// );

// --- TOOL 4: TAX SCENARIO SIMULATOR ---
export const taxSimulatorTool = ai.defineTool(
  {
    name: 'simulateTaxImpact',
    description: 'Forecasts financial liability based on different carbon tax rates.',
    inputSchema: z.object({
      userId: z.string(),
      proposedTaxRate: z.number().describe('Projected tax rate in RM per tonne (e.g., 35, 100)'),
    }),
    outputSchema: z.object({
      grossLiability: z.number(),
      netLiabilityAfterGITA: z.number(),
      savingsFromGITA: z.number(),
    }),
  },
  async ({ userId, proposedTaxRate }) => {
    // 1. Fetch User Data
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) throw new Error("User not found");
    const data = userDoc.data();

    const annualEmissions = data?.totalEmissions || 1000; // Default 1000t if missing
    const gitaCredit = data?.gitaTaxCreditBalance || 0;

    const gross = annualEmissions * proposedTaxRate;
    // GITA credits offset statutory income tax, but effectively cash-equivalent for this simulation
    const net = Math.max(0, gross - gitaCredit); 

    return {
      grossLiability: gross,
      netLiabilityAfterGITA: net,
      savingsFromGITA: gross - net,
    };
  }
);

// --- TOOL 5: INVESTMENT SIMULATOR (ROI) ---
export const investmentSimulatorTool = ai.defineTool(
  {
    name: 'simulateInvestment',
    description: 'Calculates ROI for a specific green asset investment.',
    inputSchema: z.object({
      assetCost: z.number(),
      monthlyEnergySavings: z.number().describe('Estimated reduction in kWh/month'),
      gitaEligible: z.boolean(),
    }),
    outputSchema: z.object({
      paybackPeriodMonths: z.number(),
      firstYearCashflow: z.number(),
      taxSavings: z.number(),
    }),
  },
  async ({ assetCost, monthlyEnergySavings, gitaEligible }) => {
    const TNB_RATE = 0.50; // RM 0.50 per kWh (Commercial estimate)
    const TAX_RATE = 0.24; // 24% Corporate Tax Rate

    const annualEnergySavingsRM = monthlyEnergySavings * TNB_RATE * 12;
    
    // GITA Calculation: 100% of Capex is an allowance against statutory income
    // The actual cash value is Tax Rate * Allowance
    const taxSavings = gitaEligible ? (assetCost * TAX_RATE) : 0;
    
    const effectiveCost = assetCost - taxSavings;
    const paybackMonths = (effectiveCost / (annualEnergySavingsRM / 12));

    return {
      paybackPeriodMonths: parseFloat(paybackMonths.toFixed(1)),
      firstYearCashflow: annualEnergySavingsRM + taxSavings - assetCost,
      taxSavings: taxSavings,
    };
  }
);

// --- MAIN AGENT FLOW ---
// Has defined inputs
// Has defined outputs
// Contains async logic
// Can call tools
// WHY export: so it can be called as a Firebase callable HTTPS function
export const wiraBotFlow = ai.defineFlow(
  {
    name: 'wiraBot',
    // defines input and output schemas for type safety
    inputSchema: z.object({
      userId: z.string(),
      message: z.string(),
    }),
    outputSchema: z.object({
      text: z.string(),
      toolCallsUsed: z.array(z.string()).optional(),
    }),
  },
  async ({ userId, message }) => {
    // 1. Fetch User Context (Optional but recommended for personalized answers)
    const userDoc = await db.collection('users').doc(userId).get();
    // converts user data to prompt friendly string
    const userContext = userContextToString(userDoc.data());

    // 2. Call Gemini with Tools
    const { text, toolRequests} = await ai.generate({
      model: googleAI.model('gemini-2.5-flash'),
      prompt: `
        You are Wira, the AI Carbon Consultant for Malaysian SMEs.
        User Context: ${userContext}
        
        Your Goal: Help the user minimize carbon tax liability and maximize GITA tax incentives.
        Tone: Professional, encouraging, and financially savvy (focus on "savings" not just "environment").
        
        Current Query: ${message}
      `,
      tools: [
        searchMyHijauTool,
        //industryBenchmarkTool,
        //transportEstimatorTool,
        taxSimulatorTool,
        investmentSimulatorTool,
        //draftInquiryTool
      ],
      maxTurns: 1, // max tool call cycles
      // Configuration to ensure reliable tool calling on Flash model
      config: {
        temperature: 0.2, // Low temp for precise tool use
      }
    });

    return {
      text: text,
      toolCallsUsed: toolRequests?.map(tc => tc.toolRequest.name),
    };
  }
);

//////// ALTERNATIVE USING STREAMING METHOD ////////
// const { stream } = ai.generateStream({
//   prompt: 'What is the weather in Baltimore?',
//   tools: [getWeather],
// });

// for await (const chunk of stream) {
//   console.log(chunk);
// }

// SAMPLE OUTPUT:
// {index: 0, role: "model", content: [{text: "Okay, I'll check the weather"}]}
// {index: 0, role: "model", content: [{text: "for Baltimore."}]}
// // toolRequests will be emitted as a single chunk by most models
// {index: 0, role: "model", content: [{toolRequest: {name: "getWeather", input: {location: "Baltimore"}}}]}
// // when streaming multiple messages, Genkit increments the index and indicates the new role
// {index: 1, role: "tool", content: [{toolResponse: {name: "getWeather", output: "Temperature: 68 degrees\nStatus: Cloudy."}}]}
// {index: 2, role: "model", content: [{text: "The weather in Baltimore is 68 degrees and cloudy."}]}
























/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

//////////////////////////import {setGlobalOptions} from "firebase-functions";
// import {onRequest} from "firebase-functions/https";
// import * as logger from "firebase-functions/logger";

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
/////////////////////////setGlobalOptions({ maxInstances: 10 });

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
