import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'package:kira_app/data/models/line_item.dart';
import '../models/receipt.dart';

// class GenkitService {
//   // TODO: Replace with your teammate's Genkit API URL
//   static const String baseUrl = 'YOUR_GENKIT_API_URL_HERE';
  
//   /// Process receipt image with Genkit API
//   /// 
//   /// Genkit will:
//   /// 1. Extract data using Gemini OCR
//   /// 2. Calculate CO2 emissions
//   /// 3. Determine GITA eligibility
//   /// 4. Save to Firebase Firestore
//   /// 5. Return complete receipt JSON
//   Future<Receipt> processReceipt(Uint8List imageBytes, String userId) async {
//     try {
//       print('📤 Sending receipt to Genkit API...');
//       print('   Image size: ${imageBytes.length} bytes');
//       print('   User ID: $userId');
      
//       final response = await http.post(
//         Uri.parse('$baseUrl/processReceipt'),
//         headers: {
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode({
//           'userId': userId,
//           'imageBytes': base64Encode(imageBytes),
//         }),
//       ).timeout(
//         const Duration(seconds: 30),
//         onTimeout: () {
//           throw Exception('Genkit API request timed out');
//         },
//       );
      
//       if (response.statusCode == 200) {
//         print('✅ Genkit API success');
//         final json = jsonDecode(response.body) as Map<String, dynamic>;
//         final receipt = Receipt.fromFirestore(json);
//         print('   Receipt ID: ${receipt.id}');
//         print('   Vendor: ${receipt.vendor}');
//         print('   CO2: ${receipt.co2Kg} kg');
//         return receipt;
//       } else {
//         print('❌ Genkit API error: ${response.statusCode}');
//         print('   Response: ${response.body}');
//         throw Exception('Genkit API returned status ${response.statusCode}');
//       }
//     } catch (e) {
//       print('❌ Genkit service error: $e');
//       rethrow;
//     }
//   }

//   /// Check if Genkit API is available
//   Future<bool> healthCheck() async {
//     try {
//       final response = await http.get(
//         Uri.parse('$baseUrl/health'),
//       ).timeout(const Duration(seconds: 5));
      
//       return response.statusCode == 200;
//     } catch (e) {
//       print('❌ Genkit health check failed: $e');
//       return false;
//     }
//   }
// }

class GenkitService {
  final FirebaseFunctions functions = FirebaseFunctions.instance;

  // return a json format for Genkit extractInvoice() 
  Future<Map<String, dynamic>> extractInvoice(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);
    final dataUrl = 'data:image/jpeg;base64,$base64Image';
    // refer to kira_genkit/functions/src/index.ts extractInvoiceFlow() to manipulate the imageBytes

    final result = await functions.
      httpsCallable('extractInvoice')
      .call({
        'file': dataUrl
      });

    return result.data as Map<String, dynamic>;
  }

  // return a json format for Genkit convertToGitaEntry() 
  Future<Map<String, dynamic>> convertToGitaEntry(LineItem lineItem) async {
    // refer to kira_genkit/functions/src/index.ts convertToGitaEntryFlow()

    final payload = lineItemToItemSchema(lineItem);

    final result = await functions.
      httpsCallable('convertToGitaEntry')
      .call({
        payload
      });

    return result.data as Map<String, dynamic>;
  }

  // return a json format for Genkit convertToCarbonEntry() 
  Future<Map<String, dynamic>> convertToCarbonEntry(LineItem lineItem) async {
    // refer to kira_genkit/functions/src/index.ts convertToGitaEntryFlow()

    final payload = lineItemToItemSchema(lineItem);

    final result = await functions.
      httpsCallable('convertToCarbonEntry')
      .call({
        payload
      });

    return result.data as Map<String, dynamic>;
  }

  // single source of truth to convert LineItem to match ItemSchema defined in Genkit
  Map<String, dynamic> lineItemToItemSchema(LineItem lineItem) {
    final payload = {
      'name': lineItem.name,
      'supplier': lineItem.supplier,
      'quantity': lineItem.quantity,
      'unit': lineItem.unit,
      'price': lineItem.price,
      'currency': lineItem.currency,
      'isGitaEligible': lineItem.isGitaEligible,
      'dateOfPurchase': lineItem.date.toIso8601String().split('T').first,
    };
    return payload;
  }
}
