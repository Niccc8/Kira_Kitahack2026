/**
 * Chatbot Agent Flow — "Kira" AI Carbon Consultant
 *
 * Vincent's chatbot logic (from the `chatbot` branch),
 * reorganised as a module for the unified backend
 *
 * 4 Genkit Tools:
 *   1. searchMyHijauDirectory — green product search
 *   2. simulateTaxImpact      — carbon tax forecast
 *   3. simulateInvestment     — green asset ROI
 *   4. getIndustryBenchmark   — emissions vs industry avg
 *
 * Uses LAZY initialisation so the emulator doesn't timeout.
 */

import { z } from 'zod';
import * as admin from 'firebase-admin';

// ── Firebase Admin (shared singleton) ──────────────────────
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();

// ── Lazy Genkit instance ───────────────────────────────────
// We delay Genkit + Google AI plugin init until the first
// chat request, so the Cloud Functions emulator boots fast.
let _ai: any = null;

function getAI() {
    if (_ai) return _ai;

    // Dynamic requires so the heavy modules load on first call, not at import
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

    // Register all 4 tools once
    registerTools(_ai);

    return _ai;
}

// ── Tool references (populated on first getAI() call) ──────
let _searchMyHijauTool: any;
let _taxSimulatorTool: any;
let _investmentSimulatorTool: any;
let _industryBenchmarkTool: any;

function registerTools(ai: any) {
    // ═══ TOOL 1: MyHijau Green Product Search ═══
    _searchMyHijauTool = ai.defineTool(
        {
            name: 'searchMyHijauDirectory',
            description:
                'Searches the MyHijau directory for certified green products or services. Use when user asks for eco-friendly alternatives.',
            inputSchema: z.object({
                query: z.string().describe('Search keyword, e.g. "solar panel", "LED lighting"'),
            }),
            outputSchema: z.object({
                results: z.array(
                    z.object({
                        name: z.string(),
                        manufacturer: z.string(),
                        certExpiry: z.string(),
                    })
                ),
            }),
        },
        async ({ query }: { query: string }) => {
            console.log(`[TOOL] Searching MyHijau for: ${query}`);
            const snapshot = await db
                .collection('myhijaudirectory')
                .where('keywords', 'array-contains', query.toLowerCase())
                .limit(5)
                .get();

            const results = snapshot.docs.map((doc: any) => {
                const d = doc.data();
                return {
                    name: d.name || doc.id,
                    manufacturer: d.manufacturer || 'Unknown',
                    certExpiry: d.certExpiry || 'N/A',
                };
            });
            return { results };
        }
    );

    // ═══ TOOL 2: Carbon Tax Simulator ═══
    _taxSimulatorTool = ai.defineTool(
        {
            name: 'simulateTaxImpact',
            description:
                'Forecasts financial liability based on different carbon tax rates. Use when user asks about tax projections.',
            inputSchema: z.object({
                userId: z.string(),
                proposedTaxRate: z.number().describe('Tax rate in RM per tonne (e.g. 35, 100)'),
            }),
            outputSchema: z.object({
                grossLiability: z.number(),
                netLiabilityAfterGITA: z.number(),
                savingsFromGITA: z.number(),
            }),
        },
        async ({ userId, proposedTaxRate }: { userId: string; proposedTaxRate: number }) => {
            console.log(`[TOOL] Simulating Tax for User: ${userId} at Rate: ${proposedTaxRate}`);
            const userDoc = await db.collection('users').doc(userId).get();
            if (!userDoc.exists) throw new Error('User not found');
            const data = userDoc.data();

            const annualEmissions = data?.totalEmissions || data?.totalcarbonemission || 1000;
            const gitaCredit = data?.gitaTaxCreditBalance || 0;

            const gross = annualEmissions * proposedTaxRate;
            const net = Math.max(0, gross - gitaCredit);

            return {
                grossLiability: gross,
                netLiabilityAfterGITA: net,
                savingsFromGITA: gross - net,
            };
        }
    );

    // ═══ TOOL 3: Green Investment ROI Simulator ═══
    _investmentSimulatorTool = ai.defineTool(
        {
            name: 'simulateInvestment',
            description:
                'Calculates ROI for a green asset investment using the greenAssets collection.',
            inputSchema: z.object({
                assetId: z.string().describe('ID of the green asset from the database'),
                monthlyEnergyUsageKwh: z.number().describe('Estimated monthly energy usage in kWh. Default 5000 if unknown.'),
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
            const assetDoc = await db.collection('greenAssets').doc(assetId).get();
            if (!assetDoc.exists) throw new Error('Asset not found in ROI database.');

            const asset = assetDoc.data()!;
            const TNB_RATE = 0.5;
            const TAX_RATE = 0.24;

            const annualEnergyKwh = monthlyEnergyUsageKwh * 12;
            const energyOffsetKwh = annualEnergyKwh * (asset.annualEnergyOffsetPercent || 0.3);
            const annualSavingsRM = energyOffsetKwh * TNB_RATE - (asset.annualMaintenanceRM || 0);

            const taxSavingsRM = asset.gitaEligible ? (asset.capexRM || 0) * TAX_RATE : 0;
            const effectiveCost = (asset.capexRM || 0) - taxSavingsRM;
            const paybackPeriodYears = annualSavingsRM > 0 ? effectiveCost / annualSavingsRM : 99;
            const totalLifetimeSavings = annualSavingsRM * (asset.lifetimeYears || 20);
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
            description:
                'Compares user carbon intensity vs industry average. Use ONLY when user asks how they compare to competitors.',
            inputSchema: z.object({ userId: z.string() }),
            outputSchema: z.object({
                userIntensity: z.number(),
                industryAverage: z.number(),
                performance: z.string(),
            }),
        },
        async ({ userId }: { userId: string }) => {
            console.log(`[TOOL] Benchmarking User: ${userId}`);
            const userDoc = await db.collection('users').doc(userId).get();
            const userData = userDoc.data();
            if (!userData || !userData.industry) throw new Error('User data incomplete');

            const totalEmissions = userData.totalcarbonemission || userData.totalEmissions || 0;
            const userIntensity = (totalEmissions * 1000) / (userData.annualRevenue || 1);
            const statsDoc = await db.collection('industry_stats').doc(userData.industry).get();
            const avgIntensity = statsDoc.exists ? statsDoc.data()?.averageIntensity : 0.0002;

            const isGood = userIntensity < avgIntensity;
            const performance = isGood ? 'Better (Lower Carbon)' : 'Worse (Higher Carbon)';
            const percentDiff = ((Math.abs(userIntensity - avgIntensity) / avgIntensity) * 100).toFixed(0);

            return {
                userIntensity,
                industryAverage: avgIntensity,
                performance: `${percentDiff}% ${performance} than industry average.`,
            };
        }
    );
}

// ═══════════════════════════════════════════════════════════
//  HELPER: Fetch Receipt Context for Contextual Chat
// ═══════════════════════════════════════════════════════════
async function getReceiptContext(userId: string, receiptId: string | undefined): Promise<string> {
    if (!receiptId) return '';
    try {
        const doc = await db.collection('users').doc(userId).collection('receipts').doc(receiptId).get();
        if (!doc.exists) return '\n[System] User selected a receipt, but ID was not found.';

        const data = doc.data();
        return `
=== SELECTED RECEIPT/INVOICE CONTEXT ===
Receipt ID: ${receiptId}
Vendor: ${data?.vendor || 'Unknown'}
Date: ${data?.date || 'N/A'}
Line Items: ${JSON.stringify(data?.lineItems || [])}
================================
`;
    } catch (error) {
        console.error('Error fetching receipt:', error);
        return '\n[System] Error retrieving receipt details.';
    }
}

// ═══════════════════════════════════════════════════════════
//  MAIN AGENT FLOW — wiraBotFlow
// ═══════════════════════════════════════════════════════════
export async function wiraBotFlow(input: {
    userId: string;
    message: string;
    receiptId?: string;
}): Promise<string> {
    const ai = getAI(); // Lazy init — first call takes ~2s, subsequent calls instant
    const { userId, message, receiptId } = input;

    // Fetch user profile for context
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();
    const userProfile = userData
        ? `Industry: ${userData.industry}, Annual Revenue: RM${userData.annualRevenue}, Total Emissions: ${userData.totalcarbonemission || userData.totalEmissions || 0}t.`
        : 'Guest User';

    const receiptContext = await getReceiptContext(userId, receiptId);
    console.log(`\n--- [ChatAgent] Processing request for ${userId} ---`);

    const { text } = await ai.generate({
        prompt: `
      You are Kira, an AI Carbon Consultant helping Malaysian SMEs.
      
      -- USER PROFILE --
      ${userProfile}
      
      -- ACTIVE CONTEXT --
      ${receiptContext ? `User has attached this receipt/invoice to the chat:${receiptContext}` : 'No specific receipt attached.'}
      
      -- INSTRUCTIONS --
      1. Answer the user's query: "${message}"
      2. If a receipt is attached and the user asks how to reduce it, look at the 'Line Items' array. Extract keywords (like 'electricity', 'fuel', 'packaging') and use the searchMyHijauDirectory tool to find green alternatives.
      3. Be conversational, professional, and helpful. Use RM for currency.
    `,
        tools: [_searchMyHijauTool, _taxSimulatorTool, _investmentSimulatorTool, _industryBenchmarkTool],
    });

    return text;
}
