import 'package:kira_app/data/models/line_item.dart';

class GitaItem extends LineItem{
  final int tier;
  final String sector;
  final String technology;
  final String asset;
  final double gitaAllowance;

  GitaItem({
    required super.id,
    required super.name,
    required super.supplier,
    required super.quantity,
    required super.unit,
    required super.price,
    required super.currency,
    required super.isGitaEligible,
    required super.date,
    required this.tier,
    required this.sector,
    required this.technology,
    required this.asset,
    required this.gitaAllowance,
  });

  factory GitaItem.fromJson(Map<String, dynamic> json) {
    final base = LineItem.fromJson(json);

    return GitaItem(
      id: base.id,
      name: base.name,
      supplier: base.supplier,
      quantity: base.quantity,
      unit: base.unit,
      price: base.price,
      currency: base.currency,
      isGitaEligible: base.isGitaEligible,
      date: base.date,
      tier: json['tier'] as int,
      sector: json['sector'] as String,
      technology: json['technology'] as String,
      asset: json['asset'] as String,
      gitaAllowance: (json['gitaAllowance'] as num).toDouble(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'tier': tier,
      'sector': sector,
      'technology': technology,
      'asset': asset,
      'gitaAllowance': gitaAllowance,
    };
  }
}