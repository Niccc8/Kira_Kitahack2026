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
  Future<Receipt> processReceiptHttp(Uint8List imageBytes, String userId) async {
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
        const Duration(seconds: 180), // Longer timeout for AI processing
        onTimeout: () {
          throw Exception('Genkit API request timed out');
        },
      );
      
      if (response.statusCode == 200) {
        print('✅ Genkit API success');
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Debug: Print the JSON structure
        print('   Response keys: ${json.keys.toList()}');
        
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

  // ════════════════════════════════════════════════════════
  //  CHATBOT — wiraChat endpoint (from chatbot branch)
  //  Completely separate from the OCR processReceiptHttp above.
  // ════════════════════════════════════════════════════════

  /// Send a chat message to the Kira AI chatbot (wiraBot Genkit flow).
  ///
  /// [userId]    – Firebase Auth UID of the current user
  /// [message]   – The user's chat message
  /// [receiptId] – Optional receipt ID for contextual questions
  ///
  /// Returns the AI assistant's reply as a plain string.
  Future<String> sendChatMessage({
    required String userId,
    required String message,
    String? receiptId,
  }) async {
    try {
      print('💬 Sending chat to wiraBot...');
      print('   User: $userId');
      print('   Message: $message');
      if (receiptId != null) print('   Receipt context: $receiptId');

      final body = <String, dynamic>{
        'userId': userId,
        'message': message,
      };
      if (receiptId != null) body['receiptId'] = receiptId;

      final response = await http.post(
        Uri.parse('$baseUrl/wiraChat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 60), // Agent tool calls may take a while
        onTimeout: () {
          throw Exception('Chat request timed out');
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = json['reply'] as String? ?? json['text'] as String? ?? '';
        print('✅ Kira replied (${reply.length} chars)');
        return reply;
      } else {
        print('❌ Chat error ${response.statusCode}: ${response.body}');
        throw Exception('Chat API returned status ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Chat service error: $e');
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
