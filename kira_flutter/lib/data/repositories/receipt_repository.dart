/// Receipt Repository
/// 
/// NOTE: This repository is deprecated. Receipts are now managed through:
/// - GenkitService for processing (saves directly to Firestore)
/// - Firestore streams via receipt_providers.dart for reading
/// 
/// This file is kept for backwards compatibility but is no longer actively used.
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../models/receipt.dart';

/// Repository for managing receipts (in-memory)
/// 
/// DEPRECATED: Use GenkitService and Firestore providers instead
class ReceiptRepository {
  final List<Receipt> _receipts = [];
  bool _initialized = false;
  
  /// Initialize (no-op for in-memory)
  Future<void> init() async {
    _initialized = true;
  }
  
  /// Process image and save receipt (from file path - mobile/desktop)
  /// 
  /// DEPRECATED: Use GenkitService.processReceipt() instead
  @Deprecated('Use GenkitService.processReceipt() instead')
  Future<Receipt> processReceipt(String imagePath) async {
    throw UnimplementedError(
      'ReceiptRepository.processReceipt is deprecated. '
      'Use GenkitService.processReceipt() instead, which saves directly to Firestore.'
    );
  }
  
  /// Process image and save receipt (from bytes - web compatible)
  /// 
  /// DEPRECATED: Use GenkitService.processReceipt() instead
  @Deprecated('Use GenkitService.processReceipt() instead')
  Future<Receipt> processReceiptFromBytes(List<int> imageBytes, String imagePath) async {
    throw UnimplementedError(
      'ReceiptRepository.processReceiptFromBytes is deprecated. '
      'Use GenkitService.processReceipt() instead, which saves directly to Firestore.'
    );
  }
  
  /// Get all receipts
  Future<List<Receipt>> getAllReceipts() async {
    return List.from(_receipts);
  }
  
  /// Get receipts by scope
  Future<List<Receipt>> getReceiptsByScope(int scope) async {
    return _receipts.where((r) => r.scope == scope).toList();
  }
  
  /// Get receipts by date range
  Future<List<Receipt>> getReceiptsByDateRange(DateTime start, DateTime end) async {
    return _receipts
        .where((r) => r.date.isAfter(start) && r.date.isBefore(end))
        .toList();
  }
  
  /// Get total CO2 by scope (in tonnes)
  Future<double> getTotalCO2ByScope(int scope) async {
    final total = _receipts
        .where((r) => r.scope == scope)
        .fold<double>(0.0, (sum, r) => sum + r.co2Tonnes);
    return total;
  }
  
  /// Get total CO2 (all scopes, in tonnes)
  Future<double> getTotalCO2() async {
    final total = _receipts.fold<double>(0.0, (sum, r) => sum + r.co2Tonnes);
    return total;
  }
  
  /// Delete receipt
  Future<void> deleteReceipt(String id) async {
    _receipts.removeWhere((r) => r.id == id);
  }
  
  /// Clear all receipts
  Future<void> clearAll() async {
    _receipts.clear();
  }
}
