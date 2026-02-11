/// Receipt Data Model - With Line Items
/// 
/// Represents a receipt with multiple line items.

import 'line_item.dart';

class Receipt {
  // ═══════════════════════════════════════════════
  // RECEIPT HEADER (6 fields)
  // ═══════════════════════════════════════════════
  final String id;
  final String vendor;         // "Hardware Store"
  final DateTime date;
  final double total;          // Total RM (sum of all line items)
  final String? imageUrl;      // Firebase Storage URL
  final DateTime createdAt;
  
  // ═══════════════════════════════════════════════
  // LINE ITEMS (array)
  // ═══════════════════════════════════════════════
  final List<LineItem> lineItems;
  
  Receipt({
    required this.id,
    required this.vendor,
    required this.date,
    required this.total,
    this.imageUrl,
    required this.createdAt,
    required this.lineItems,
  });
  
  // ═══════════════════════════════════════════════
  // COMPUTED PROPERTIES (Aggregate from line items)
  // ═══════════════════════════════════════════════
  
  /// Total CO2 emissions (kg)
  double get co2Kg => lineItems.fold(0.0, (sum, item) => sum + item.co2Kg);
  
  /// Total CO2 emissions (tonnes)
  double get co2Tonnes => co2Kg / 1000;
  
  /// Is GITA eligible? (true if ANY item is eligible)
  bool get gitaEligible => lineItems.any((item) => item.gitaEligible);
  
  /// Total GITA tax allowance
  double get gitaAllowance => lineItems.fold(0.0, (sum, item) => sum + item.gitaSavings);
  
  /// Primary scope (most common scope in line items)
  int get scope {
    if (lineItems.isEmpty) return 3;
    
    // Count scopes
    final scopeCounts = <int, int>{};
    for (final item in lineItems) {
      scopeCounts[item.scope] = (scopeCounts[item.scope] ?? 0) + 1;
    }
    
    // Return most common
    return scopeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
  
  /// Primary category (most common category)
  String get category {
    if (lineItems.isEmpty) return 'other';
    
    final categoryCounts = <String, int>{};
    for (final item in lineItems) {
      categoryCounts[item.category] = (categoryCounts[item.category] ?? 0) + 1;
    }
    
    return categoryCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
  
  /// Display name (vendor + date or first item)
  String get name {
    if (lineItems.isEmpty) {
      return '$vendor Receipt';
    }
    
    if (lineItems.length == 1) {
      return lineItems.first.name;
    }
    
    return '$vendor (${lineItems.length} items)';
  }
  
  /// GITA eligible items only
  List<LineItem> get gitaItems => lineItems.where((item) => item.gitaEligible).toList();
  
  /// Highest GITA tier present
  int? get gitaTier {
    final eligibleItems = gitaItems;
    if (eligibleItems.isEmpty) return null;
    
    final tiers = eligibleItems
        .map((item) => item.gitaTier)
        .where((tier) => tier != null)
        .cast<int>()
        .toList();
    
    if (tiers.isEmpty) return null;
    
    return tiers.reduce((a, b) => a < b ? a : b); // Lower tier number = better
  }
  
  /// Primary GITA category
  String? get gitaCategory {
    final eligibleItems = gitaItems;
    if (eligibleItems.isEmpty) return null;
    
    return eligibleItems.first.gitaCategory;
  }
  
  // ═══════════════════════════════════════════════
  // FROM FIRESTORE
  // ═══════════════════════════════════════════════
  
  factory Receipt.fromFirestore(Map<String, dynamic> json) {
    final lineItemsJson = json['lineItems'] as List<dynamic>? ?? [];
    
    // Safely parse date strings
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      try {
        if (dateValue is String) {
          return DateTime.parse(dateValue);
        }
        return DateTime.now();
      } catch (e) {
        return DateTime.now();
      }
    }
    
    return Receipt(
      id: (json['id'] as String?)?.toString() ?? '',
      vendor: (json['vendor'] as String?)?.toString() ?? 'Unknown Vendor',
      date: parseDate(json['date']),
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'] as String?,
      createdAt: parseDate(json['createdAt']),
      lineItems: lineItemsJson
          .map((item) {
            try {
              return LineItem.fromJson(item as Map<String, dynamic>);
            } catch (e) {
              print('Error parsing line item: $e');
              return null;
            }
          })
          .whereType<LineItem>()
          .toList(),
    );
  }
  
  // ═══════════════════════════════════════════════
  // TO FIRESTORE
  // ═══════════════════════════════════════════════
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor': vendor,
      'date': date.toIso8601String(),
      'total': total,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'lineItems': lineItems.map((item) => item.toJson()).toList(),
    };
  }
  
  // ═══════════════════════════════════════════════
  // COPY WITH
  // ═══════════════════════════════════════════════
  
  Receipt copyWith({
    String? id,
    String? vendor,
    DateTime? date,
    double? total,
    String? imageUrl,
    DateTime? createdAt,
    List<LineItem>? lineItems,
  }) {
    return Receipt(
      id: id ?? this.id,
      vendor: vendor ?? this.vendor,
      date: date ?? this.date,
      total: total ?? this.total,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      lineItems: lineItems ?? this.lineItems,
    );
  }
}
