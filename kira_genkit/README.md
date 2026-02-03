# Kira Carbon Tracker - Genkit (by Ex in progress)

## How to Run 🚀

1. **Install Dependencies**
   ```bash
   cd kira_genkit/functions
   firebase init genkit
   npm install dotenv
   ```

2. **Create .env**
   ```
   Create kira_genkit\functions\.env and add GOOGLE_GENAI_API_KEY=<YOUR GENAI API KEY>
   ```

3. **Run Genkit UI**
   ```bash
   npx genkit start -- npx tsx --watch src/genkit-sample.ts
   ```
   or
   ```bash
   npx genkit start -- npx tsx --watch src/index.ts
   ```
   NOTE: the genkit-sample.ts is a testing, from Genkit docs whereas the index.ts is the real work for Kira KitaHAck 2026. 
   Click on the link generated (eg: http://localhost:4000)