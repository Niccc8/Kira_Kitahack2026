/// Storage Service
/// 
/// Handles file uploads to Firebase Storage.
library;

import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload receipt image to Firebase Storage
  /// Returns the public download URL
  Future<String> uploadReceiptImage(Uint8List bytes, String userId) async {
    try {
      // Create a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'receipts/${userId}_$timestamp.jpg';
      
      // Create a reference
      final ref = _storage.ref().child(fileName);
      
      // Upload metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'timestamp': timestamp.toString(),
        },
      );
      
      // Upload file
      print('📤 Uploading image to Storage: $fileName');
      await ref.putData(bytes, metadata);
      
      // Get download URL
      final url = await ref.getDownloadURL();
      print('✅ Image uploaded. URL: $url');
      
      return url;
    } catch (e) {
      print('❌ Storage upload failed: $e');
      rethrow;
    }
  }
}
