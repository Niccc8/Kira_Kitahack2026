/// Line Item Model
/// 
/// Represents a single item within a receipt.

class LineItem {
  final String name;           // "Solar Panel 10kW"
  final String category;       // "electricity"
  final double quantity;       // 10
  final String unit;           // "kW"
  final double price;          // RM 50000
  final double co2Kg;          // kg CO2 for this item
  final int scope;             // 1, 2, or 3
  
  // GITA
  final bool gitaEligible;
  final int? gitaTier;
  final String? gitaCategory;
  final double? gitaAllowance;
  
  LineItem({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.co2Kg,
    required this.scope,
    required this.gitaEligible,
    this.gitaTier,
    this.gitaCategory,
    this.gitaAllowance,
  });
  
  // Computed
  double get co2Tonnes => co2Kg / 1000;
  double get gitaSavings => gitaAllowance ?? 0;
  
  // From Firestore
  factory LineItem.fromJson(Map<String, dynamic> json) {
    return LineItem(
      name: json['name'] as String? ?? 'Unknown Item',
      category: json['category'] as String? ?? 'other',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? 'pcs',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      co2Kg: (json['co2Kg'] as num?)?.toDouble() ?? 0.0,
      scope: json['scope'] as int? ?? 3,
      gitaEligible: json['gitaEligible'] as bool? ?? false,
      gitaTier: json['gitaTier'] as int?,
      gitaCategory: json['gitaCategory'] as String?,
      gitaAllowance: (json['gitaAllowance'] as num?)?.toDouble(),
    );
  }
  
  // To Firestore
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'co2Kg': co2Kg,
      'scope': scope,
      'gitaEligible': gitaEligible,
      'gitaTier': gitaTier,
      'gitaCategory': gitaCategory,
      'gitaAllowance': gitaAllowance,
    };
  }
}
