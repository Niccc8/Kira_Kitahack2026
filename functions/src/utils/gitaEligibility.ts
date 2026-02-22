/**
 * GITA (Green Investment Tax Allowance) Eligibility Checker
 * 
 * Determines if an item is eligible for Malaysian GITA tax incentives
 * and calculates the tax allowance.
 */

interface Item {
  name: string;
  category: string;
  quantity: number;
  unit: string;
  price: number;
}

interface GITAInfo {
  eligible: boolean;
  tier?: number;
  category?: string;
  allowance?: number;
}

/**
 * Check GITA eligibility for a line item
 * 
 * GITA eligible categories:
 * - Solar panels and renewable energy equipment
 * - Energy-efficient equipment
 * - Electric vehicles and charging infrastructure
 * - Waste management and recycling equipment
 * - Water conservation equipment
 * 
 * Tiers:
 * - Tier 1: 100% tax allowance (best green tech)
 * - Tier 2: 60% tax allowance (good green tech)
 * - Tier 3: 40% tax allowance (moderate green tech)
 */
export function checkGITAEligibility(item: Item): GITAInfo {
  const name = item.name || '';
  const category = item.category || 'other';
  const price = item.price || 0;
  const nameLower = name.toLowerCase();

  // Check for solar/renewable energy
  if (
    nameLower.includes('solar') ||
    nameLower.includes('photovoltaic') ||
    nameLower.includes('pv panel') ||
    nameLower.includes('renewable') ||
    (category === 'electricity' && nameLower.includes('panel'))
  ) {
    return {
      eligible: true,
      tier: 1,
      category: 'renewable_energy',
      allowance: price * 1.0, // 100% allowance
    };
  }

  // Check for energy-efficient equipment
  if (
    nameLower.includes('led') ||
    nameLower.includes('energy efficient') ||
    nameLower.includes('energy-efficient') ||
    nameLower.includes('inverter') ||
    nameLower.includes('heat pump')
  ) {
    return {
      eligible: true,
      tier: 2,
      category: 'energy_efficiency',
      allowance: price * 0.6, // 60% allowance
    };
  }

  // Check for electric vehicles
  if (
    nameLower.includes('electric vehicle') ||
    nameLower.includes('ev') ||
    nameLower.includes('charging station') ||
    nameLower.includes('charger') ||
    (category === 'transport' && nameLower.includes('electric'))
  ) {
    return {
      eligible: true,
      tier: 1,
      category: 'electric_vehicle',
      allowance: price * 1.0, // 100% allowance
    };
  }

  // Check for waste management
  if (
    nameLower.includes('recycling') ||
    nameLower.includes('waste management') ||
    nameLower.includes('compost') ||
    nameLower.includes('biogas')
  ) {
    return {
      eligible: true,
      tier: 2,
      category: 'waste_management',
      allowance: price * 0.6, // 60% allowance
    };
  }

  // Check for water conservation
  if (
    nameLower.includes('water conservation') ||
    nameLower.includes('rainwater') ||
    nameLower.includes('water recycling') ||
    nameLower.includes('greywater')
  ) {
    return {
      eligible: true,
      tier: 3,
      category: 'water_conservation',
      allowance: price * 0.4, // 40% allowance
    };
  }

  // Check for green building materials
  if (
    category === 'materials' &&
    (nameLower.includes('green') ||
      nameLower.includes('sustainable') ||
      nameLower.includes('eco-friendly'))
  ) {
    return {
      eligible: true,
      tier: 3,
      category: 'green_materials',
      allowance: price * 0.4, // 40% allowance
    };
  }

  // Not eligible
  return {
    eligible: false,
  };
}



