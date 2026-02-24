import { enableFirebaseTelemetry } from '@genkit-ai/firebase';
import * as functions from 'firebase-functions';
import { onCall, onRequest } from 'firebase-functions/v2/https'; // Use V2 for better performance
import { processReceiptFlow } from './flows/processReceipt';
import { wiraBotFlow } from './flows/chatAgent';

// Note: Ensure googleAI is initialized inside your flow file 
// or a shared genkit config to avoid "Plugin already registered" errors.
enableFirebaseTelemetry();

// ═══════════════════════════════════════════════════════════
//  GENKIT FLOW 1: AI OCR — Receipt Processing
// ═══════════════════════════════════════════════════════════

/**
 * Callable Function (Best for Web/Mobile SDKs)
 * Automatically handles auth context and CORS
 */
export const processReceipt = onCall({
  memory: "1GiB", // OCR usually needs xmore memory
  timeoutSeconds: 120, // Gemini calls can take a few seconds
}, async (request) => {
  const { userId, imageBytes } = request.data;

  if (!userId || !imageBytes) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing userId or imageBytes');
  }

  try {
    return await processReceiptFlow({ userId, imageBytes });
  } catch (error: any) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * HTTP Request Function (Standard Webhook/REST)
 */
export const processReceiptHttp = onRequest({ cors: true }, async (req, res) => {
  // Check method
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    const { userId, imageBytes } = req.body;
    if (!userId || !imageBytes) {
      res.status(400).send('Missing required fields');
      return;
    }

    const result = await processReceiptFlow({ userId, imageBytes });
    res.status(200).json(result);
  } catch (error: any) {
    console.error('Error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ═══════════════════════════════════════════════════════════
//  GENKIT FLOW 2: AI Chatbot — Kira Carbon Consultant
// ═══════════════════════════════════════════════════════════

/**
 * HTTP POST endpoint for the chatbot.
 * Body: { userId: string, message: string, receiptId?: string }
 * Returns: { reply: string }
 */
export const wiraChat = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  try {
    const { userId, message, receiptId } = req.body;

    if (!userId || !message) {
      res.status(400).json({ error: 'Missing required fields: userId and message' });
      return;
    }

    const reply = await wiraBotFlow({ userId, message, receiptId });
    res.status(200).json({ reply });
  } catch (error: any) {
    console.error('Agent execution error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// ═══════════════════════════════════════════════════════════
//  Health Check
// ═══════════════════════════════════════════════════════════

export const health = onRequest({ cors: true }, (req, res) => {
  res.status(200).json({ status: 'healthy', service: 'kira-backend' });
});