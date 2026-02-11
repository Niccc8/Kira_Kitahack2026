import { z } from 'zod';
import * as admin from 'firebase-admin';
import { genkit } from 'genkit';
import { googleAI } from '@genkit-ai/googleai';
import { calculateCO2 } from '../utils/co2Calculator';
import { checkGITAEligibility } from '../utils/gitaEligibility';

// Initialize Firebase Admin once
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const storage = admin.storage();

// 1. Initialize Genkit properly
const ai = genkit({
  plugins: [
    googleAI({ 
      apiKey: process.env.GOOGLE_GENAI_API_KEY 
    })
  ],
  // Use the 2026 stable model ID
  model: googleAI.model('gemini-2.5-flash'), 
});

// Improved Schema with descriptions to help Gemini's accuracy
const ReceiptDataSchema = z.object({
  vendor: z.string().min(1).describe('Name of the store or service provider'),
  date: z.string().describe('Date of purchase in ISO or YYYY-MM-DD format'),
  lineItems: z.array(z.object({
    name: z.string().min(1),
    category: z.enum(['electricity', 'transport', 'materials', 'other']),
    quantity: z.number().default(1),
    unit: z.string().default('pcs'),
    price: z.number().min(0),
  })).min(1),
});

type ReceiptData = z.infer<typeof ReceiptDataSchema>;

/**
 * Process Receipt Flow
 */
export async function processReceiptFlow(input: {
  userId: string;
  imageBytes: string; // Expected as Base64 string
}) {
  const { userId, imageBytes } = input;
  const now = new Date();
  const receiptRef = db.collection('users').doc(userId).collection('receipts').doc();
  const receiptId = receiptRef.id;

  // Step 1: Extract data using Gemini Vision
  const extractedData = await extractReceiptData(imageBytes);

  // Step 2: Enrich line items
  const processedLineItems = extractedData.lineItems.map((item) => {
    const co2Kg = calculateCO2(item);
    const gitaInfo = checkGITAEligibility(item);

    return {
      ...item,
      co2Kg,
      scope: determineScope(item.category),
      gitaEligible: gitaInfo.eligible,
      gitaTier: gitaInfo.tier,
      gitaCategory: gitaInfo.category,
      gitaAllowance: gitaInfo.allowance,
    };
  });

  // Step 3: Totals & Dates
  const total = processedLineItems.reduce((sum, item) => sum + item.price, 0);
  // Ensure the date is valid; fallback to 'now' if OCR fails
  const parsedDate = isNaN(Date.parse(extractedData.date)) ? now : new Date(extractedData.date);
  
  // Ensure vendor is not empty
  const vendor = extractedData.vendor?.trim() || 'Unknown Vendor';

  // Step 4: Storage Upload
  let imageUrl = await uploadReceiptImage(userId, receiptId, imageBytes);

  const receipt = {
    id: receiptId,
    vendor: vendor,
    date: parsedDate.toISOString(),
    total: total || 0,
    imageUrl: imageUrl || null,
    createdAt: now.toISOString(),
    lineItems: processedLineItems || [],
  };

  // Step 5: Firestore Save
  await receiptRef.set(receipt);

  return receipt;
}

/**
 * Gemini-powered OCR and Classification
 */
async function extractReceiptData(imageBytes: string): Promise<ReceiptData> {
  try {
    const response = await ai.generate({
      // Use a versioned string ID. 'gemini-1.5-flash-latest' or 'gemini-1.5-flash-002' 
      // are more stable than the generic 'gemini-1.5-flash'
      model: 'googleai/gemini-2.5-flash',
      prompt: [
        { text: "Extract all items from this receipt. Classify each into: electricity, transport, or materials." },
        {
          media: {
            contentType: 'image/jpeg',
            url: `data:image/jpeg;base64,${imageBytes}`,
          },
        },
      ],
      output: { schema: ReceiptDataSchema },
    });

    if (!response.output) throw new Error("Gemini failed to parse receipt structure.");
    return response.output;

  } catch (error: any) {
    console.error('OCR Extraction Error:', error);
    // Log the full error to help us see if it's still a 404
    throw new Error(`Extraction failed: ${error.message}`);
  }
}

/**
 * Helper: Upload Base64 to Firebase Storage
 * 
 * Note:
 * - We do NOT use signed URLs here because the Cloud Functions service account
 *   does not have `iam.serviceAccounts.signBlob` permission by default.
 * - Instead, we simply upload the file. The Flutter app then resolves the
 *   download URL client‑side via `FirebaseStorage.instance.ref(path).getDownloadURL()`,
 *   which uses Firebase Auth and your Storage rules.
 */
async function uploadReceiptImage(userId: string, receiptId: string, base64: string): Promise<string | null> {
  try {
    const bucket = storage.bucket();
    const filePath = `users/${userId}/receipts/${receiptId}.jpg`;
    const buffer = Buffer.from(base64, 'base64');

    const file = bucket.file(filePath);
    
    // Upload without public ACL (uniform bucket-level access + Admin SDK)
    await file.save(buffer, {
      contentType: 'image/jpeg',
      metadata: {
        userId,
        receiptId,
        uploadedAt: new Date().toISOString(),
      },
    });

    // We intentionally DO NOT generate a signed URL here to avoid requiring
    // extra IAM permissions on the service account.
    // Return null so the caller falls back to resolving via Storage path.
    return null;
  } catch (err) {
    console.error('Storage Upload Failed:', err);
    return null; // Return null but don't crash the whole flow
  }
}

function determineScope(category: string): 1 | 2 | 3 {
  const scopes: Record<string, 1 | 2 | 3> = {
    electricity: 2,
    transport: 3,
    materials: 3
  };
  return scopes[category] || 3;
}