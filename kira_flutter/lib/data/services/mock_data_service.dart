/// Mock Data Service
/// 
/// Provides realistic mock receipt data for testing and development.
/// Call uploadMockData() to populate Firebase with sample receipts.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/receipt.dart';
import '../models/line_item.dart';

class MockDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload mock receipts to Firebase for a specific user
  Future<void> uploadMockData(String userId) async {
    print('📦 Uploading mock data for user: $userId');
    
    final mockReceipts = _generateMockReceipts(userId);
    
    for (final receipt in mockReceipts) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('receipts')
          .doc(receipt.id)
          .set(receipt.toJson());
      
      print('✅ Uploaded: ${receipt.vendor} - RM${receipt.total.toStringAsFixed(2)}');
    }
    
    print('🎉 Mock data upload complete! ${mockReceipts.length} receipts added.');
  }

  /// Generate realistic mock receipts
  List<Receipt> _generateMockReceipts(String userId) {
    final now = DateTime.now();
    
    return [
      // 1. Electricity Bill - Scope 2
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_1',
        vendor: 'Tenaga Nasional Berhad (TNB)',
        date: DateTime(now.year, now.month - 1, 15),
        total: 850.00,
        imageUrl: 'https://picsum.photos/seed/tnb/400/600',
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Industrial Electricity Consumption',
            quantity: 2500.0,
            unit: 'kWh',
            price: 0.34,
            co2Kg: 1750.0, // 0.7 kg CO2/kWh
            scope: 2,
            category: 'utilities',
            gitaEligible: false,
            gitaAllowance: 0,
          ),
        ],
      ),

      // 2. Diesel Fuel - Scope 1
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_2',
        vendor: 'Petronas Station',
        date: DateTime(now.year, now.month - 1, 20),
        total: 320.50,
        imageUrl: 'https://picsum.photos/seed/fuel/400/600',
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Diesel Fuel for Company Vehicles',
            quantity: 150.0,
            unit: 'L',
            price: 2.14,
            co2Kg: 405.0, // 2.7 kg CO2/L  
            scope: 1,
            category: 'transport',
            gitaEligible: false,
            gitaAllowance: 0,
          ),
        ],
      ),

      // 3. Business Travel - Scope 3
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_3',
        vendor: 'AirAsia',
        date: DateTime(now.year, now.month - 2, 10),
        total: 450.00,
        imageUrl: 'https://picsum.photos/seed/flight/400/600',
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Business Flight KUL-SIN Return',
            quantity: 1.0,
            unit: 'ticket',
            price: 450.00,
            co2Kg: 180.0, // ~90 kg per flight
            scope: 3,
            category: 'transport',
            gitaEligible: false,
            gitaAllowance: 0,
          ),
        ],
      ),

      // 4. Solar Panels - GITA Eligible - Scope 2
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_4',
        vendor: 'Green Energy Solutions Sdn Bhd',
        date: DateTime(now.year, now.month - 2, 5),
        total: 15500.00,
        imageUrl: 'https://picsum.photos/seed/solar/400/600',
        createdAt: now,
        lineItems: [
          LineItem(
            name: '5kW Solar Panel System',
            quantity: 1.0,
            unit: 'system',
            price: 15500.00,
            co2Kg: 500.0, // Manufacturing + transport + installation
            scope: 2,
            category: 'utilities',
            gitaEligible: true,
            gitaTier: 1,
            gitaCategory: 'Solar PV System',
            gitaAllowance: 3100.00, // 20% GITA allowance
          ),
        ],
      ),

      // 5. Office Supplies - Scope 3
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_5',
        vendor: 'Office Depot',
        date: DateTime(now.year, now.month, 3),
        total: 280.00,
        imageUrl: 'https://picsum.photos/seed/office/400/600',
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Printer Paper (Recycled)',
            quantity: 10.0,
            unit: 'ream',
            price: 18.00,
            co2Kg: 12.0,
            scope: 3,
            category: 'office',
            gitaEligible: false,
            gitaAllowance: 0,
          ),
          LineItem(
            name: 'Office Furniture',
            quantity: 1.0,
            unit: 'set',
            price: 100.00,
            co2Kg: 45.0,
            scope: 3,
            category: 'office',
            gitaEligible: false,
            gitaAllowance: 0,
          ),
        ],
      ),

      // 6. Natural Gas - Scope 1
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_6',
        vendor: 'Gas Malaysia',
        date: DateTime(now.year, now.month - 3, 28),
        total: 680.00,
        imageUrl: 'https://picsum.photos/seed/gas/400/600',
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Natural Gas for Manufacturing',
            quantity: 350.0,
            unit: 'm³',
            price: 1.94,
            co2Kg: 735.0, // 2.1 kg CO2/m³
            scope: 1,
            category: 'utilities',
            gitaEligible: false,
            gitaAllowance: 0,
          ),
        ],
      ),

      // 7. Waste Management - Scope 3
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_7',
        vendor: 'Alam Flora Waste Management',
        date: DateTime(now.year, now.month - 4, 12),
        total: 420.00,
        imageUrl: 'https://picsum.photos/seed/waste/400/600',
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Industrial Waste Disposal',
            quantity: 500.0,
            unit: 'kg',
            price: 0.84,
            co2Kg: 150.0,
            scope: 3,
            category: 'waste',
            gitaEligible: false,
            gitaAllowance: 0,
          ),
        ],
      ),

      // 8. Electric Vehicle Charging - GITA Eligible - Scope 2
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_8',
        vendor: 'ChargEV',
        date: DateTime(now.year, now.month, 8),
        total: 45.00,
        imageUrl: 'https://picsum.photos/seed/ev/400/600',
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'EV Charging Sessions',
            quantity: 150.0,
            unit: 'kWh',
            price: 0.30,
            co2Kg: 105.0,
            scope: 2,
            category: 'transport',
            gitaEligible: true,
            gitaTier: 2,
            gitaCategory: 'Electric Vehicle',
            gitaAllowance: 9.00, // Small GITA benefit
          ),
        ],
      ),

      // 9. Raw Materials - Scope 3
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_9',
        vendor: 'Industrial Supplies Co',
        date: DateTime(now.year, now.month - 5, 22),
        total: 3200.00,
        imageUrl: 'https://picsum.photos/seed/materials/400/600',
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Steel Sheets',
            quantity: 500.0,
            unit: 'kg',
            price: 5.00,
            co2Kg: 900.0, // 1.8 kg CO2/kg steel
            scope: 3,
            category: 'materials',
            gitaEligible: false,
            gitaAllowance: 0,
          ),
          LineItem(
            name: 'Aluminum Bars',
            quantity: 200.0,
            unit: 'kg',
            price: 9.00,
            co2Kg: 2200.0, // 11 kg CO2/kg aluminum
            scope: 3,
            category: 'materials',
            gitaEligible: false,
            gitaAllowance: 0,
          ),
        ],
      ),

      // 10. Water Bill - Scope 3
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_10',
        vendor: 'Air Selangor',
        date: DateTime(now.year, now.month - 1, 5),
        total: 125.00,
        imageUrl: 'https://picsum.photos/seed/water/400/600',
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Industrial Water Supply',
            quantity: 350.0,
            unit: 'm³',
            price: 0.36,
            co2Kg: 0.7, // Very low emissions
            scope: 3,
            category: 'utilities',
            gitaEligible: false,
            gitaAllowance: 0,
          ),
        ],
      ),

      // 11. LED Lighting Upgrade - GITA Eligible - Scope 2
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_11',
        vendor: 'EcoLite Solutions',
        date: DateTime(now.year, now.month - 3, 18),
        total: 2800.00,
        imageUrl: 'https://picsum.photos/seed/led/400/600',
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Energy-Efficient LED Bulbs (100 units)',
            quantity: 100.0,
            unit: 'units',
            price: 28.00,
            co2Kg: 50.0, // Manufacturing + packaging + transport
            scope: 2,
            category: 'utilities',
            gitaEligible: true,
            gitaTier: 2,
            gitaCategory: 'Energy Efficiency',
            gitaAllowance: 560.00, // 20% GITA
          ),
        ],
      ),

      // 12. Company Car Fuel - Scope 1
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_12',
        vendor: 'Shell Station',
        date: DateTime(now.year, now.month, 12),
        total: 95.00,
        imageUrl: 'https://picsum.photos/seed/shell/400/600',
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'RON 95 Petrol',
            quantity: 40.0,
            unit: 'L',
            price: 2.38,
            co2Kg: 92.0, // 2.3 kg CO2/L
            scope: 1,
            category: 'transport',
            gitaEligible: false,
            gitaAllowance: 0,
          ),
        ],
      ),
      
      // 13. [NEW] Green Supplies Multi-Item - Scope 3 & GITA
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_13',
        vendor: 'Sustainable Packaging Sdn Bhd',
        date: DateTime(now.year, now.month, 2),
        total: 2450.00,
        imageUrl: 'https://picsum.photos/seed/packaging/400/600',
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Recycled Cardboard Boxes',
            quantity: 2000.0,
            unit: 'units',
            price: 0.85,
            co2Kg: 120.0,
            scope: 3,
            category: 'materials',
            gitaEligible: true, // Example GITA eligibility
            gitaTier: 2,
            gitaCategory: 'Green Packaging',
            gitaAllowance: 340.00,
          ),
          LineItem(
            name: 'Biodegradable Packing Peanuts',
            quantity: 50.0,
            unit: 'kg',
            price: 15.00,
            co2Kg: 15.0,
            scope: 3,
            category: 'materials',
            gitaEligible: true,
            gitaTier: 2,
            gitaCategory: 'Green Packaging',
            gitaAllowance: 150.00,
          ),
        ],
      ),
    ];
  }

  /// Clear all receipts for a user (for testing)
  Future<void> clearUserReceipts(String userId) async {
    final receiptsRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('receipts');
    
    final snapshot = await receiptsRef.get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
    
    print('🗑️ Cleared all receipts for user: $userId');
  }
}
