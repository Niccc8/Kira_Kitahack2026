## Instructions
1. install node.js
2. install Firebase CLI
- npm install -g firebase-tools
3. install Flutter SDK
- run flutter pub get
4. run firebase login
5. run firebase init, select 
    ◉ Firestore
    ◉ Functions
    ◉ Genkit
    ◉ Emulators
- choose Google AI
- no telemetry collection
- name firebase-backend
- select
    ❯◉ Authentication Emulator: port 9099
    ◉ Functions Emulator: 5001
    ◉ Firestore Emulator: 8080
6. run flutter run -d chrome