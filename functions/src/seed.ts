// script to insert fake data into local emulator
import * as admin from 'firebase-admin';

// Connect to local emulator
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
admin.initializeApp({ projectId: 'demo-wira' });

const db = admin.firestore();

async function seed() {
  console.log("🌱 Seeding database...");

  // 1. Create a Fake User
  await db.collection('users').doc('user123').set({
    industry: 'Manufacturing',
    annualRevenue: 5000000,
    lastMonthEmissions: 120,
    totalEmissions: 1440, // Annual
    gitaTaxCreditBalance: 50000 
  });
  console.log("✅ User 'user123' created.");

  // 2. Create Green Assets (for searchMyHijauTool)
  await db.collection('myhijau_assets').add({
    name: 'Solar Panel PV-200',
    supplier: 'SolarX Sdn Bhd',
    keywords: ['solar', 'panel', 'energy'],
    expiryDate: '2027-12-31'
  });
  
  await db.collection('myhijau_assets').add({
    name: 'High Efficiency Chiller',
    supplier: 'CoolTech MY',
    keywords: ['chiller', 'cooling', 'hvac'],
    expiryDate: '2026-06-30'
  });
  console.log("✅ MyHijau assets created.");
}

seed().catch(console.error);