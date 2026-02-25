/// Mock Data Service
/// 
/// Provides realistic mock receipt data for testing and development.
/// Call uploadMockData() to populate Firebase with sample receipts.
/// Images are uploaded to Firebase Storage under the user's path.

import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/receipt.dart';
import '../models/line_item.dart';

class MockDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload mock receipts to Firebase for a specific user.
  /// Also uploads demo receipt images to Firebase Storage.
  Future<void> uploadMockData(String userId) async {
    print('📦 Uploading mock data for user: $userId');
    
    // Step 1: Upload demo images to Firebase Storage
    print('🖼️ Uploading demo receipt images to Storage...');
    final imageUrls = await _uploadDemoImages(userId);
    
    // Step 2: Generate receipts with real Storage URLs
    final mockReceipts = _generateMockReceipts(userId, imageUrls);
    
    // Step 3: Write receipts to Firestore
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

  /// Upload the 3 demo receipt images to Firebase Storage.
  /// Returns a map of { 'utility' | 'fuel' | 'invoice' : gs://URL }.
  Future<Map<String, String>> _uploadDemoImages(String userId) async {
    final assets = {
      'utility': 'assets/images/utility_bill.png',
      'fuel': 'assets/images/fuel_receipt.png',
      'invoice': 'assets/images/office_invoice.png',
    };

    final urls = <String, String>{};

    for (final entry in assets.entries) {
      try {
        // Read bundled asset bytes
        final data = await rootBundle.load(entry.value);
        final bytes = data.buffer.asUint8List();

        // Upload to Storage under: receipts/demo/{userId}_{key}.png
        final storagePath = 'receipts/demo/${userId}_${entry.key}.png';
        final ref = _storage.ref().child(storagePath);

        final metadata = SettableMetadata(
          contentType: 'image/png',
          customMetadata: {'userId': userId, 'type': 'demo_receipt'},
        );

        await ref.putData(bytes, metadata);

        // Store the gs:// URL (StorageImage uses refFromURL → getData)
        urls[entry.key] = 'gs://${_storage.bucket}/$storagePath';
        print('  ✅ ${entry.key}: ${urls[entry.key]}');
      } catch (e) {
        print('  ⚠️ Failed to upload ${entry.key} image: $e');
        // Fallback: no image
        urls[entry.key] = '';
      }
    }

    return urls;
  }

  /// Generate realistic mock receipts with Firebase Storage image URLs
  List<Receipt> _generateMockReceipts(String userId, Map<String, String> imgs) {
    final now = DateTime.now();
    final utilityImg = imgs['utility'] ?? '';
    final fuelImg = imgs['fuel'] ?? '';
    final invoiceImg = imgs['invoice'] ?? '';

    return [
      // 1. Electricity Bill - Scope 2
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_1',
        vendor: 'Tenaga Nasional Berhad (TNB)',
        date: DateTime(now.year, now.month - 1, 15),
        total: 850.00,
        imageUrl: utilityImg,
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Industrial Electricity Consumption',
            quantity: 2500.0,
            unit: 'kWh',
            price: 0.34,
            co2Kg: 1750.0,
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
        imageUrl: fuelImg,
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Diesel Fuel for Company Vehicles',
            quantity: 150.0,
            unit: 'L',
            price: 2.14,
            co2Kg: 405.0,
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
        imageUrl: fuelImg,
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Business Flight KUL-SIN Return',
            quantity: 1.0,
            unit: 'ticket',
            price: 450.00,
            co2Kg: 180.0,
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
        imageUrl: invoiceImg,
        createdAt: now,
        lineItems: [
          LineItem(
            name: '5kW Solar Panel System',
            quantity: 1.0,
            unit: 'system',
            price: 15500.00,
            co2Kg: 500.0,
            scope: 2,
            category: 'utilities',
            gitaEligible: true,
            gitaTier: 1,
            gitaCategory: 'Solar PV System',
            gitaAllowance: 3100.00,
          ),
        ],
      ),

      // 5. Office Supplies - Scope 3
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_5',
        vendor: 'Office Depot',
        date: DateTime(now.year, now.month, 3),
        total: 280.00,
        imageUrl: invoiceImg,
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
        imageUrl: utilityImg,
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Natural Gas for Manufacturing',
            quantity: 350.0,
            unit: 'm³',
            price: 1.94,
            co2Kg: 735.0,
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
        imageUrl: invoiceImg,
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
        imageUrl: fuelImg,
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
            gitaAllowance: 9.00,
          ),
        ],
      ),

      // 9. Raw Materials - Scope 3
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_9',
        vendor: 'Industrial Supplies Co',
        date: DateTime(now.year, now.month - 5, 22),
        total: 3200.00,
        imageUrl: invoiceImg,
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Steel Sheets',
            quantity: 500.0,
            unit: 'kg',
            price: 5.00,
            co2Kg: 900.0,
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
            co2Kg: 2200.0,
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
        imageUrl: utilityImg,
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Industrial Water Supply',
            quantity: 350.0,
            unit: 'm³',
            price: 0.36,
            co2Kg: 0.7,
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
        imageUrl: invoiceImg,
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'Energy-Efficient LED Bulbs (100 units)',
            quantity: 100.0,
            unit: 'units',
            price: 28.00,
            co2Kg: 50.0,
            scope: 2,
            category: 'utilities',
            gitaEligible: true,
            gitaTier: 2,
            gitaCategory: 'Energy Efficiency',
            gitaAllowance: 560.00,
          ),
        ],
      ),

      // 12. Company Car Fuel - Scope 1
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_12',
        vendor: 'Shell Station',
        date: DateTime(now.year, now.month, 12),
        total: 95.00,
        imageUrl: fuelImg,
        createdAt: now,
        lineItems: [
          LineItem(
            name: 'RON 95 Petrol',
            quantity: 40.0,
            unit: 'L',
            price: 2.38,
            co2Kg: 92.0,
            scope: 1,
            category: 'transport',
            gitaEligible: false,
            gitaAllowance: 0,
          ),
        ],
      ),
      
      // 13. Green Supplies Multi-Item - Scope 3 & GITA
      Receipt(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}_13',
        vendor: 'Sustainable Packaging Sdn Bhd',
        date: DateTime(now.year, now.month, 2),
        total: 2450.00,
        imageUrl: invoiceImg,
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
            gitaEligible: true,
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
