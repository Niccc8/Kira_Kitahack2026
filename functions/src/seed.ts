import * as admin from 'firebase-admin';

// Connect to local emulator
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
// Only initialize if not already initialized
if (!admin.apps.length) {
    admin.initializeApp({ projectId: 'demo-wira' });
}

const db = admin.firestore();

async function seed() {
  console.log("🌱 Seeding database...");

  // 1. Create/Reset User
  await db.collection('users').doc('user123').set({
    industry: 'Manufacturing',
    annualRevenue: 10000000, // RM 10 Million
    totalEmissions: 1440, // 1,440 Tonnes CO2
    gitaTaxCreditBalance: 50000 
  });
  console.log("✅ User 'user123' created.");

  // 2. Create Green Assets
  await db.collection('myhijau_assets').add({
    name: 'Solar Panel PV-200',
    supplier: 'SolarX Sdn Bhd',
    keywords: ['solar', 'panel', 'energy'],
    expiryDate: '2027-12-31'
  });
  
  // 3. Create Industry Benchmarks (NEW)
  // We store "Carbon Intensity" = kgCO2 per RM Revenue
  await db.collection('industry_stats').doc('Manufacturing').set({
    averageIntensity: 0.0002, // Industry Standard: 0.0002 kgCO2 per RM
    unit: 'kgCO2e/RM'
  });
  console.log("✅ Industry stats created.");
}

seed().catch(console.error);