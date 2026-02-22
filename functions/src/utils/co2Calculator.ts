/**
 * CO2 Emission Calculator
 * 
 * Calculates CO2 emissions based on item category, quantity, and unit
 */

interface Item {
  name: string;
  category: string;
  quantity: number;
  unit: string;
  price: number;
}

/**
 * Calculate CO2 emissions in kg for a line item
 * 
 * Uses emission factors based on category:
 * - Electricity: kg CO2 per kWh (Malaysia grid average ~0.6 kg CO2/kWh)
 * - Transport: kg CO2 per km (varies by vehicle type)
 * - Materials: kg CO2 per RM spent (varies by material type)
 */
export function calculateCO2(item: Item): number {
  const category = item.category || 'other';
  const quantity = item.quantity || 1;
  const unit = item.unit || 'pcs';
  const price = item.price || 0;

  switch (category) {
    case 'electricity':
      // Malaysia grid emission factor: ~0.6 kg CO2/kWh
      if (unit.toLowerCase().includes('kw') || unit.toLowerCase().includes('kwh')) {
        return quantity * 0.6;
      }
      // If unit is different, estimate based on price (rough conversion)
      // Average electricity price in Malaysia: ~RM 0.30/kWh
      const estimatedKwh = price / 0.3;
      return estimatedKwh * 0.6;

    case 'transport':
      // Average car emission: ~0.2 kg CO2/km
      if (unit.toLowerCase().includes('km')) {
        return quantity * 0.2;
      }
      // Estimate based on price (average RM 0.50/km)
      const estimatedKm = price / 0.5;
      return estimatedKm * 0.2;

    case 'materials':
      // Material emissions vary widely
      // Use average factor: ~2 kg CO2 per RM 100 spent
      return (price / 100) * 2;

    default:
      // Generic factor for other items: ~1 kg CO2 per RM 100
      return (price / 100) * 1;
  }
}



