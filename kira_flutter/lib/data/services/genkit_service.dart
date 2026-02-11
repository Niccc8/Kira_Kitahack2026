import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/receipt.dart';

class GenkitService {
  // TODO: Replace with your teammate's Genkit API URL
  static const String baseUrl = 'https://us-central1-kira26.cloudfunctions.net';
  
  /// Process receipt image with Genkit API
  /// 
  /// Genkit will:
  /// 1. Extract data using Gemini OCR
  /// 2. Calculate CO2 emissions
  /// 3. Determine GITA eligibility
  /// 4. Save to Firebase Firestore
  /// 5. Return complete receipt JSON
  Future<Receipt> processReceipt(Uint8List imageBytes, String userId) async {
    try {
      print('📤 Sending receipt to Genkit API...');
      print('   Image size: ${imageBytes.length} bytes');
      print('   User ID: $userId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/processReceiptHttp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'imageBytes': base64Encode(imageBytes),
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Genkit API request timed out');
        },
      );
      
      if (response.statusCode == 200) {
        print('✅ Genkit API success');
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Debug: Print the JSON structure
        print('   Response keys: ${json.keys.toList()}');
        print('   Has id: ${json.containsKey('id')}, value: ${json['id']}');
        print('   Has vendor: ${json.containsKey('vendor')}, value: ${json['vendor']}');
        print('   Has lineItems: ${json.containsKey('lineItems')}, count: ${(json['lineItems'] as List?)?.length ?? 0}');
        
        try {
          final receipt = Receipt.fromFirestore(json);
          print('   Receipt ID: ${receipt.id}');
          print('   Vendor: ${receipt.vendor}');
          print('   CO2: ${receipt.co2Kg} kg');
          return receipt;
        } catch (e, stackTrace) {
          print('❌ Error parsing receipt: $e');
          print('   Stack trace: $stackTrace');
          print('   JSON data: $json');
          rethrow;
        }
      } else {
        print('❌ Genkit API error: ${response.statusCode}');
        print('   Response: ${response.body}');
        throw Exception('Genkit API returned status ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Genkit service error: $e');
      rethrow;
    }
  }
  
  /// Check if Genkit API is available
  Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Genkit health check failed: $e');
      return false;
    }
  }
}
