## Instructions
0. chatbot branch
1. initialise node 
- npm init -y
2. install genkit core, google AI plugin, firebase, typescript
- npm install genkit @genkit-ai/google-genai firebase-admin firebase-functions zod
- npm install --save-dev typescript ts-node @types/node
3. initialize typescript
- npx tsc --init
```JSON
{
  "compilerOptions": {
    "target": "es2018",
    "module": "commonjs",
    "strict": false,
    "esModuleInterop": true,
    "skipLibCheck": true
  }
}
```
4. Get API key
- env: GOOGLE_GENAI_API_KEY
5. Database setup - use firebase emulator
- npm install -g firebase-tools
- firebase init emulators
i  Port for auth already configured: 9099
i  Port for functions already configured: 5001
i  Port for firestore already configured: 8080
i  Emulator UI already enabled with port: (automatic)
- firebase emulators:start
✅ java -version → Java 25 detected
✅ Firestore Emulator started (port 8080)
✅ Auth Emulator started (port 9099)
✅ Emulator UI running → http://127.0.0.1:4000
✅ “✔ All emulators ready!
- view emulator UI at http://127.0.0.1:4000/

6. create mock dataset for testing
create seed.ts
- run: npx ts-node seed.ts

7. paste original code in index.ts

8. paste updated test run code in run_agent.ts
- cd into functions folder and run the following
  - npm install @genkit-ai/google-genai
  - npm install genkit zod
  - verify: npm list @genkit-ai/google-genai

- RUN: npx ts-node run_agent.ts
- RUN ANYWHERE: dotenvx run -- npx ts-node run_agent.ts

9. add select specific invoice feature - frontend call instructions
In your frontend (React, Vue, etc.), you will have a dropdown. When the user sends a message, you check if an invoice is selected in that dropdown.

- Populating the Dropdown (Frontend Code) You likely already know this, but you just query the invoices collection where userId == currentUser.

- Calling the Bot (Frontend Code) This is how you structure the call to the Firebase Callable Function.

Sample:
```JAVASCRIPT
import { getFunctions, httpsCallable } from "firebase/functions";

// Initialize functions
const functions = getFunctions();
const wiraBot = httpsCallable(functions, 'wiraBot');

async function handleSendMessage() {
  const userMessage = "How can I reduce emissions for this?"; // User input
  const selectedInvoiceId = "inv_8823_TN"; // From your dropdown state (or null)

  try {
    const result = await wiraBot({
      userId: "user123",        // Current user
      message: userMessage,     // The question
      invoiceId: selectedInvoiceId // Pass ID if selected, otherwise undefined
    });

    console.log("Wira says:", result.data.text);
    // Display result.data.text in your chat UI
    
  } catch (error) {
    console.error("Error calling WiraBot:", error);
  }
}
```




### Test results
1. Normal Chat
--- Processing Request for user123 ---
Context: Industry: Manufacturing, Annual Emissions: 1440t.
Response 1: Hello! I'm Wira, your AI Carbon Consultant. I specialize in helping manufacturing businesses like yours minimize their carbon tax liability. With your annual emissions around 1440 tonnes, I can help you find ways to reduce that and save on taxes. How can I assist you today?

2. searchMyHijauDirectory
--- Processing Request for user123 ---
Context: Industry: Manufacturing, Annual Emissions: 1440t.
[TOOL] Searching MyHijau for: solar panel
Response 2: Great! I found "Solar Panel PV-200" from SolarX Sdn Bhd, approved until 2027-12-31.

This is a good step towards reducing your carbon footprint. To help you further minimize your carbon tax liability, I can simulate the tax impact of using this solar panel.

Would you like me to proceed with that simulation?

3. simulateTaxCalculation
--- Processing Request for user123 ---
Context: Industry: Manufacturing, Annual Emissions: 1440t.
[TOOL] Simulating Tax for User: user123 at Rate: 35
Response 3: Your carbon tax liability will be RM 50,400.

--- TEST 4: Investment Simulator ---

--- Processing Request for user123 ---
Context: Industry: Manufacturing, Annual Emissions: 1440t.
[TOOL] Simulating Investment for: solar panels
Response: Investing in solar panels is definitely worth considering! Based on our simulations, an investment in solar panels with an estimated cost of RM50,000 could result in tax savings of RM12,000, bringing your net cost down to RM38,000. Even better, you could see a full payback on your investment in just 2.5 years.

This looks like a strong financial case for reducing your carbon footprint. Would you like to explore other green investment options or perhaps see how a different tax rate might impact your liabilities?

--- TEST 5: Industry Benchmark ---

--- Processing Request for user123 ---
Context: Industry: Manufacturing, Annual Emissions: 1440t.
[TOOL] Benchmarking User: user123
Response: Your carbon intensity is 0.144 tonnes CO2e per RM of revenue, which is 71900% higher than the industry average of 0.0002 tonnes CO2e per RM. This indicates a significant opportunity for improvement in your carbon footprint.

Would you like to explore options to reduce your emissions and minimize carbon tax liability?