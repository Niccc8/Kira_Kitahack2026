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
