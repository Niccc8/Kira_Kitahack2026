# Kira Genkit Backend

Backend server using Google Genkit for processing receipts and calculating carbon emissions.

## Setup

1. Install dependencies:
```bash
cd functions
npm install
```

2. Set up Firebase:
```bash
firebase login
firebase use kira26
```

3. Build the project:
```bash
npm run build
```

## Development

Run locally with Firebase emulators:
```bash
npm run serve
```

## Deployment

Deploy to Firebase Functions:
```bash
npm run deploy
```

## API Endpoints

### POST /processReceipt
Process a receipt image and extract data.

**Request:**
```json
{
  "userId": "user123",
  "imageBytes": "base64-encoded-image"
}
```

**Response:**
```json
{
  "id": "receipt-id",
  "vendor": "Store Name",
  "date": "2024-01-15T00:00:00.000Z",
  "total": 500.00,
  "lineItems": [...],
  "createdAt": "2024-01-15T10:00:00.000Z"
}
```

### GET /health
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:00:00.000Z",
  "service": "kira-genkit-backend"
}
```

## Genkit Flows

- `processReceipt`: Main flow for processing receipts
  - Extracts data using Gemini Vision
  - Calculates CO2 emissions
  - Determines GITA eligibility
  - Saves to Firestore



