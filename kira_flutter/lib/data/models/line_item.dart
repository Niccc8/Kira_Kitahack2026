/// Line Item Model
/// 
/// Represents a single item within a receipt.

// class LineItem {
//   final String name;           // "Solar Panel 10kW"
//   final String category;       // "electricity"
//   final double quantity;       // 10
//   final String unit;           // "kW"
//   final double price;          // RM 50000
//   final double co2Kg;          // kg CO2 for this item
//   final int scope;             // 1, 2, or 3
  
//   // GITA
//   final bool gitaEligible;
//   final int? gitaTier;
//   final String? gitaCategory;
//   final double? gitaAllowance;
  
//   LineItem({
//     required this.name,
//     required this.category,
//     required this.quantity,
//     required this.unit,
//     required this.price,
//     required this.co2Kg,
//     required this.scope,
//     required this.gitaEligible,
//     this.gitaTier,
//     this.gitaCategory,
//     this.gitaAllowance,
//   });
  
//   // Computed
//   double get co2Tonnes => co2Kg / 1000;
//   double get gitaSavings => gitaAllowance ?? 0;
  
//   // From Firestore
//   factory LineItem.fromJson(Map<String, dynamic> json) {
//     return LineItem(
//       name: json['name'] as String,
//       category: json['category'] as String,
//       quantity: (json['quantity'] as num).toDouble(),
//       unit: json['unit'] as String,
//       price: (json['price'] as num).toDouble(),
//       co2Kg: (json['co2Kg'] as num).toDouble(),
//       scope: json['scope'] as int,
//       gitaEligible: json['gitaEligible'] as bool,
//       gitaTier: json['gitaTier'] as int?,
//       gitaCategory: json['gitaCategory'] as String?,
//       gitaAllowance: (json['gitaAllowance'] as num?)?.toDouble(),
//     );
//   }
  
//   // To Firestore
//   Map<String, dynamic> toJson() {
//     return {
//       'name': name,
//       'category': category,
//       'quantity': quantity,
//       'unit': unit,
//       'price': price,
//       'co2Kg': co2Kg,
//       'scope': scope,
//       'gitaEligible': gitaEligible,
//       'gitaTier': gitaTier,
//       'gitaCategory': gitaCategory,
//       'gitaAllowance': gitaAllowance,
//     };
//   }
// }

class LineItem {
  final String id;
  final String name;  
  final String supplier;       
  final double quantity;       
  final String unit;           
  final double price;          
  final String currency;
  final bool isGitaEligible;
  final DateTime date;
  
  LineItem({
    required this.id,
    required this.name,
    required this.supplier,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.currency,
    required this.isGitaEligible,
    required this.date,
  });
  
  // From Firestore
  factory LineItem.fromJson(Map<String, dynamic> json) {
    return LineItem(
      id: json['id'] as String,
      name: json['name'] as String,
      supplier: json['supplier'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
      isGitaEligible: json['gitaEligible'] as bool,
      date: DateTime.parse(json['date'] as String),
    );
  }
  
  // To Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'supplier': supplier,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'currency': currency,
      'isGitaEligible': isGitaEligible,
      'date': date.toIso8601String(),
    };
  }
}


