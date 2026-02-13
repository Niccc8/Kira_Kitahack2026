/// Item Detail Modal
/// 
/// Glassmorphism popup showing receipt/item details.
/// Supports two modes: GITA (Item focused) and Emissions (Receipt focused).
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import 'kira_card.dart';
import 'kira_badge.dart';
import '../../data/models/receipt.dart';
import '../../data/models/line_item.dart';

enum DetailType { gita, emission }

class ItemDetailModal extends StatelessWidget {
  final Receipt receipt;
  final DetailType type;
  final LineItem? focusedItem; // Required for GITA type
  
  const ItemDetailModal({
    super.key,
    required this.receipt,
    this.type = DetailType.emission,
    this.focusedItem,
  });

  @override
  Widget build(BuildContext context) {
    // Full width glassmorphism container matching KiraAIChat
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: KiraColors.bgCardSolid, // Dark solid/glass hybrid base
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: KiraColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2), // Lighter handle
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type == DetailType.gita && focusedItem != null
                                  ? focusedItem!.name
                                  : receipt.vendor,
                              style: KiraTypography.h4,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type == DetailType.gita 
                                  ? receipt.vendor 
                                  : DateFormat('d MMM yyyy, h:mm a').format(receipt.date),
                              style: KiraTypography.bodySmall.copyWith(
                                color: KiraColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          color: KiraColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1, color: Colors.white10),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (type == DetailType.gita) _buildGitaContent() else _buildEmissionContent(),
                        
                        const SizedBox(height: 32),
                        
                        // Image at Bottom
                        if (receipt.imageUrl != null) ...[
                          Text('RECEIPT/INVOICE', style: KiraTypography.sectionTitle),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              receipt.imageUrl!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 100,
                                width: double.infinity,
                                color: Colors.grey.withOpacity(0.1),
                                child: const Center(
                                  child: Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGitaContent() {
    if (focusedItem == null) return const SizedBox();
    
    final item = focusedItem!;
    final allowance = item.gitaAllowance ?? 0.0;
    
    // GITA Content designed like Emissions Popup (Summary Cards + List)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Cards Row
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Allowance',
                'RM ${_formatNumber(allowance.toInt())}',
                Icons.savings_outlined,
                KiraColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Tier',
                'Tier ${item.gitaTier ?? 1}',
                Icons.stars_outlined,
                KiraColors.primary300,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // GITA Details List
        Text('ITEM DETAILS', style: KiraTypography.sectionTitle),
        const SizedBox(height: 12),
        
        KiraCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildDetailRow('Category', item.gitaCategory ?? 'General', icon: _getCategoryIcon(item.gitaCategory ?? '')),
              const Divider(height: 24, color: Colors.white10),
              _buildDetailRow('Status', 'Verified Eligible', icon: Icons.verified, valueColor: KiraColors.success),
              const Divider(height: 24, color: Colors.white10),
              _buildDetailRow('Scope', 'Scope ${_getScopeForCategory(item.gitaCategory)}', icon: Icons.public),
              const Divider(height: 24, color: Colors.white10),
              _buildDetailRow('Cost', 'RM ${_formatNumber(item.price.toInt())}', icon: Icons.attach_money),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmissionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total CO2',
                '${receipt.co2Kg.toStringAsFixed(1)} kg',
                Icons.cloud_outlined,
                _getScopeColor(receipt.scope),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Total Cost',
                'RM ${_formatNumber(receipt.total.toInt())}',
                Icons.payments_outlined,
                KiraColors.textPrimary,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Line Items
        Text('ITEMS', style: KiraTypography.sectionTitle),
        const SizedBox(height: 12),
        ...receipt.lineItems.map((item) => _buildLineItem(item)),
      ],
    );
  }
  
  // Helpers...
  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return KiraCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: KiraTypography.h4.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: KiraTypography.labelSmall,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value, {IconData? icon, Color? valueColor}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: KiraColors.textTertiary),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            label,
            style: KiraTypography.bodyMedium.copyWith(color: KiraColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: KiraTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? KiraColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildLineItem(LineItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KiraCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: KiraTypography.bodyMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${item.quantity} ${item.unit} • RM ${_formatNumber(item.price.toInt())}',
                        style: KiraTypography.bodySmall.copyWith(color: KiraColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.co2Kg.toStringAsFixed(1)} kg',
                      style: KiraTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _getScopeColor(item.scope),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getScopeColor(int scope) {
    switch (scope) {
      case 1: return KiraColors.scope1;
      case 2: return KiraColors.scope2;
      case 3: return KiraColors.scope3;
      default: return KiraColors.textSecondary;
    }
  }
  
  // Helper to guess scope from category (mock logic)
  int _getScopeForCategory(String? category) {
    final c = (category ?? '').toLowerCase();
    if (c.contains('utilities') || c.contains('electricity')) return 2;
    if (c.contains('transport') || c.contains('vehicle')) return 1;
    return 3; // Default to Supply Chain
  }
  
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'utilities': return Icons.bolt;
      case 'transport': return Icons.directions_car;
      case 'materials': return Icons.factory;
      case 'waste': return Icons.delete_outline;
      case 'office': return Icons.business_center;
      case 'travel': return Icons.flight;
      case 'solar pv system': return Icons.wb_sunny_outlined;
      case 'energy efficiency': return Icons.lightbulb_outline;
      case 'electric vehicle': return Icons.electric_car;
      case 'green packaging': return Icons.inventory_2_outlined; 
      default: return Icons.receipt_long;
    }
  }
  
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
