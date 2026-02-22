import * as admin from 'firebase-admin';

// Connect to local emulator
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';

if (!admin.apps.length) {
    admin.initializeApp({ projectId: 'demo-wira' }); // Project ID matches run_agent.ts
}

const db = admin.firestore();

async function seed() {
  console.log("🌱 Seeding Kira mock database...");

  // --- 1. USERS COLLECTION ---
  const users = [
    { id: 'user123', companyName: "Shin Zushi Sashimi Sdn Bhd", industry: 'Food & Beverage', annualRevenue: 5000000, totalcarbonemission: 120, gitaTaxCreditBalance: 15000, companySize: "51-200" },
    { id: 'user002', companyName: "Maju Logistics", industry: 'Logistics', annualRevenue: 12000000, totalcarbonemission: 850, gitaTaxCreditBalance: 0, companySize: "11-50" },
    { id: 'user003', companyName: "TechHub Penang", industry: 'Technology', annualRevenue: 20000000, totalcarbonemission: 45, gitaTaxCreditBalance: 5000, companySize: "201-500" },
    { id: 'user004', companyName: "Klang Valley Textiles", industry: 'Manufacturing', annualRevenue: 8000000, totalcarbonemission: 1440, gitaTaxCreditBalance: 50000, companySize: "51-200" },
    { id: 'user005', companyName: "Borneo Eco Tours", industry: 'Hospitality', annualRevenue: 3000000, totalcarbonemission: 80, gitaTaxCreditBalance: 12000, companySize: "11-50" },
    { id: 'user006', companyName: "KL Sentral Retailers", industry: 'Retail', annualRevenue: 15000000, totalcarbonemission: 320, gitaTaxCreditBalance: 0, companySize: "51-200" },
    { id: 'user007', companyName: "AgroFarms Kedah", industry: 'Agriculture', annualRevenue: 4000000, totalcarbonemission: 600, gitaTaxCreditBalance: 8000, companySize: "1-10" },
    { id: 'user008', companyName: "Johor Builders", industry: 'Construction', annualRevenue: 25000000, totalcarbonemission: 2100, gitaTaxCreditBalance: 100000, companySize: "201-500" },
    { id: 'user009', companyName: "Melaka Health Clinic", industry: 'Healthcare', annualRevenue: 6000000, totalcarbonemission: 150, gitaTaxCreditBalance: 4000, companySize: "51-200" },
    { id: 'user010', companyName: "Pahang Timber", industry: 'Forestry', annualRevenue: 18000000, totalcarbonemission: 3000, gitaTaxCreditBalance: 0, companySize: "201-500" },
  ];

  for (const u of users) {
    await db.collection('users').doc(u.id).set(u);
  }
  console.log("✅ 10 Users created.");

  // --- 2. RECEIPTS SUBCOLLECTION (For user123) ---
  const receipts = [
    { id: 'receipt_001', vendor: "Sustainable Packaging Sdn Bhd", date: "2026-02-02", lineItems: [{ name: "Recycled Cardboard Boxes", category: "materials", co2Kg: 120, price: 0.85, quantity: 2000, scope: 3 }] },
    { id: 'receipt_002', vendor: "TNB", date: "2026-01-15", lineItems: [{ name: "Commercial Electricity Tariff B", category: "energy", co2Kg: 2500, price: 2500, quantity: 5000, scope: 2 }] },
    { id: 'receipt_003', vendor: "Petronas", date: "2026-01-20", lineItems: [{ name: "Diesel Fuel", category: "fuel", co2Kg: 850, price: 1200, quantity: 400, scope: 1 }] },
    { id: 'receipt_004', vendor: "AirAsia", date: "2026-01-25", lineItems: [{ name: "Business Flight KL-Penang", category: "travel", co2Kg: 150, price: 450, quantity: 2, scope: 3 }] },
    { id: 'receipt_005', vendor: "Green Waste Mgmt", date: "2026-02-01", lineItems: [{ name: "Organic Waste Disposal", category: "waste", co2Kg: 30, price: 150, quantity: 1, scope: 3 }] },
    { id: 'receipt_006', vendor: "Dell Malaysia", date: "2026-02-05", lineItems: [{ name: "Office Laptops", category: "equipment", co2Kg: 400, price: 15000, quantity: 5, scope: 3 }] },
    { id: 'receipt_007', vendor: "Syabas", date: "2026-01-28", lineItems: [{ name: "Water Usage", category: "water", co2Kg: 15, price: 80, quantity: 100, scope: 3 }] },
    { id: 'receipt_008', vendor: "Grab Corporate", date: "2026-02-10", lineItems: [{ name: "Employee Commute", category: "travel", co2Kg: 45, price: 300, quantity: 15, scope: 3 }] },
    { id: 'receipt_009', vendor: "AWS", date: "2026-02-15", lineItems: [{ name: "Cloud Server Hosting", category: "services", co2Kg: 80, price: 1200, quantity: 1, scope: 3 }] },
    { id: 'receipt_010', vendor: "Local Farm Supply", date: "2026-02-18", lineItems: [{ name: "Raw Ingredients (Fish)", category: "materials", co2Kg: 300, price: 4000, quantity: 500, scope: 3 }] },
  ];

  for (const r of receipts) {
    await db.collection('users').doc('user123').collection('receipts').doc(r.id).set(r);
  }
  console.log("✅ 10 Receipts created for user123.");

  // --- 3. MYHIJAU DIRECTORY ---
  const myHijau = [
    { id: 'mh_001', name: 'Bio-Mate Organic Composter', category: 'Recycling Equipments', keywords: ['compost', 'waste', 'organic'], supplier: 'Promise Earth Sdn Bhd', rrp: 5000 },
    { id: 'mh_002', name: 'Solar Panel PV-200', category: 'Renewable Energy', keywords: ['solar', 'panel', 'energy', 'electricity'], supplier: 'SolarX Sdn Bhd', rrp: 1200 },
    { id: 'mh_003', name: 'EcoPack Biodegradable Containers', category: 'Packaging', keywords: ['packaging', 'biodegradable', 'box', 'food'], supplier: 'GreenPack Malaysia', rrp: 50 },
    { id: 'mh_004', name: 'LED Smart Bulb Pro', category: 'Energy Efficiency', keywords: ['led', 'lighting', 'bulb', 'electricity'], supplier: 'LightTech Bhd', rrp: 25 },
    { id: 'mh_005', name: 'EV Charging Station 22kW', category: 'Transportation', keywords: ['ev', 'charger', 'electric vehicle', 'car'], supplier: 'ChargeMy', rrp: 8000 },
    { id: 'mh_006', name: 'Rainwater Harvesting Tank 500L', category: 'Water Management', keywords: ['water', 'rain', 'tank', 'harvest'], supplier: 'AquaSave', rrp: 600 },
    { id: 'mh_007', name: 'Inverter Aircon 2.0HP', category: 'Energy Efficiency', keywords: ['hvac', 'aircon', 'cooling', 'inverter'], supplier: 'CoolBreeze', rrp: 2500 },
    { id: 'mh_008', name: 'Recycled A4 Paper', category: 'Office Supplies', keywords: ['paper', 'office', 'recycled', 'printing'], supplier: 'EcoPrint', rrp: 15 },
    { id: 'mh_009', name: 'Industrial Heat Pump', category: 'Energy Efficiency', keywords: ['heat', 'pump', 'industrial', 'boiler'], supplier: 'ThermoTech', rrp: 35000 },
    { id: 'mh_010', name: 'Electric Delivery Van Model T', category: 'Transportation', keywords: ['van', 'delivery', 'ev', 'transport', 'logistics'], supplier: 'GreenDrive', rrp: 140000 },
  ];

  for (const m of myHijau) {
    await db.collection('myhijaudirectory').doc(m.id).set(m);
  }
  console.log("✅ 10 MyHijau Directory items created.");

  // --- 4. ROI DATABASE (GREEN ASSETS) ---
  const assets = [
    { id: 'solar_rooftop_10kwp', name: "Rooftop Solar 10 kWp System", category: "Renewable Energy", capexRM: 25000, annualEnergyOffsetPercent: 0.65, annualMaintenanceRM: 300, lifetimeYears: 25, co2KgPerKwh: 0.67, gitaEligible: true },
    { id: 'hvac_inverter_system', name: "Inverter Air Conditioning System", category: "Energy Efficiency", capexRM: 18000, annualEnergyOffsetPercent: 0.30, annualMaintenanceRM: 500, lifetimeYears: 15, co2KgPerKwh: 0.67, gitaEligible: true },
    { id: 'led_lighting_retrofit', name: "LED Lighting Retrofit", category: "Energy Efficiency", capexRM: 8000, annualEnergyOffsetPercent: 0.45, annualMaintenanceRM: 100, lifetimeYears: 10, co2KgPerKwh: 0.67, gitaEligible: false },
    { id: 'battery_storage_20kwh', name: "Commercial Battery Storage 20 kWh", category: "Energy Storage", capexRM: 30000, annualEnergyOffsetPercent: 0.15, annualMaintenanceRM: 400, lifetimeYears: 12, co2KgPerKwh: 0.67, gitaEligible: true },
    { id: 'electric_delivery_van', name: "Electric Delivery Van", category: "Green Mobility", capexRM: 150000, annualEnergyOffsetPercent: 0.55, annualMaintenanceRM: 2000, lifetimeYears: 8, co2KgPerKwh: 0.50, gitaEligible: true },
    { id: 'commercial_composter', name: "Industrial Organic Composter", category: "Waste Management", capexRM: 45000, annualEnergyOffsetPercent: 0.0, annualMaintenanceRM: 1200, lifetimeYears: 10, co2KgPerKwh: 0.0, gitaEligible: true },
    { id: 'ev_charger_22kw', name: "EV Charging Station 22kW", category: "Infrastructure", capexRM: 12000, annualEnergyOffsetPercent: 0.0, annualMaintenanceRM: 200, lifetimeYears: 10, co2KgPerKwh: 0.0, gitaEligible: true },
    { id: 'smart_metering_system', name: "Smart Energy Metering IoT", category: "Energy Efficiency", capexRM: 5000, annualEnergyOffsetPercent: 0.10, annualMaintenanceRM: 50, lifetimeYears: 5, co2KgPerKwh: 0.67, gitaEligible: false },
    { id: 'rainwater_harvesting', name: "Commercial Rainwater System", category: "Water Management", capexRM: 15000, annualEnergyOffsetPercent: 0.0, annualMaintenanceRM: 150, lifetimeYears: 20, co2KgPerKwh: 0.0, gitaEligible: true },
    { id: 'heat_recovery_boiler', name: "Waste Heat Recovery Boiler", category: "Energy Efficiency", capexRM: 85000, annualEnergyOffsetPercent: 0.40, annualMaintenanceRM: 3000, lifetimeYears: 15, co2KgPerKwh: 0.80, gitaEligible: true },
  ];

  for (const a of assets) {
    await db.collection('greenAssets').doc(a.id).set(a);
  }
  console.log("✅ 10 Green Assets created.");

  // --- 5. INDUSTRY STATS ---
  const stats = [
    { id: 'Food & Beverage', averageIntensity: 0.00015, unit: 'kgCO2e/RM' },
    { id: 'Manufacturing', averageIntensity: 0.00035, unit: 'kgCO2e/RM' },
    { id: 'Logistics', averageIntensity: 0.00045, unit: 'kgCO2e/RM' },
    { id: 'Technology', averageIntensity: 0.00005, unit: 'kgCO2e/RM' },
    { id: 'Retail', averageIntensity: 0.00010, unit: 'kgCO2e/RM' },
    { id: 'Agriculture', averageIntensity: 0.00025, unit: 'kgCO2e/RM' },
    { id: 'Construction', averageIntensity: 0.00040, unit: 'kgCO2e/RM' },
    { id: 'Hospitality', averageIntensity: 0.00020, unit: 'kgCO2e/RM' },
    { id: 'Healthcare', averageIntensity: 0.00012, unit: 'kgCO2e/RM' },
    { id: 'Forestry', averageIntensity: 0.00050, unit: 'kgCO2e/RM' },
  ];

  for (const s of stats) {
    await db.collection('industry_stats').doc(s.id).set(s);
  }
  console.log("✅ 10 Industry Stats created.");
  console.log("🎉 Seeding complete!");
}

seed().catch(console.error);