/// Emissions Screen
/// 
/// CO₂ emissions display with scope breakdown and receipt items.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../shared/widgets/kira_card.dart';
import '../../../shared/widgets/item_detail_modal.dart';
import '../../../shared/widgets/period_selector.dart';
import '../../../providers/receipt_providers.dart';
import '../../../data/models/receipt.dart';

/// Emissions screen implementation
class EmissionsScreen extends ConsumerStatefulWidget {
  const EmissionsScreen({super.key});

  @override
  ConsumerState<EmissionsScreen> createState() => _EmissionsScreenState();
}

class _EmissionsScreenState extends ConsumerState<EmissionsScreen> {
  String _period = 'Year';
  int _selectedScope = 2;
  
  /// Filter receipts by period
  List<Receipt> _filterByPeriod(List<Receipt> receipts) {
    final now = DateTime.now();
    switch (_period) {
      case 'Today':
        return receipts.where((r) =>
          r.date.year == now.year && r.date.month == now.month && r.date.day == now.day
        ).toList();
      case 'Week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return receipts.where((r) => r.date.isAfter(weekAgo)).toList();
      case 'Month':
        return receipts.where((r) =>
          r.date.year == now.year && r.date.month == now.month
        ).toList();
      case 'Year':
      default:
        return receipts.where((r) => r.date.year == now.year).toList();
    }
  }
  
  // Scope info (static)
  final List<Map<String, dynamic>> _scopeInfo = [
    {'id': 1, 'name': 'Scope 1', 'label': 'Direct', 'icon': Icons.factory_outlined, 'color': KiraColors.scope1},
    {'id': 2, 'name': 'Scope 2', 'label': 'Electricity', 'icon': Icons.bolt, 'color': KiraColors.scope2},
    {'id': 3, 'name': 'Scope 3', 'label': 'Supply Chain', 'icon': Icons.local_shipping_outlined, 'color': KiraColors.scope3},
  ];

  @override
  Widget build(BuildContext context) {
    final totalCO2Async = ref.watch(totalCO2Provider);
    final receiptsAsync = ref.watch(receiptsStreamProvider);
    
    return receiptsAsync.when(
      data: (allReceipts) {
        // Apply period filter
        final receipts = _filterByPeriod(allReceipts);
        // Calculate emissions in kg (no conversion)
        final totalCO2 = receipts.fold(0.0, (sum, r) => sum + r.co2Kg);
        final scopeReceipts = receipts.where((r) => r.scope == _selectedScope).toList();
        final scopeCO2 = scopeReceipts.fold(0.0, (sum, r) => sum + r.co2Kg);
        final currentScope = _scopeInfo.firstWhere((s) => s['id'] == _selectedScope);
        
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Section
              _buildHeroSection(totalCO2, 0), // No change calculation yet
              
              // Scope Selector
              _buildScopeSelector(currentScope, scopeReceipts, totalCO2, scopeCO2),
              
              const SizedBox(height: 20),
              
              // Receipt Items
              _buildReceiptItems(currentScope, scopeReceipts),
              
              const SizedBox(height: 14),
              
              // Tip Card
              _buildTipCard(),
              
              const SizedBox(height: KiraSpacing.screenBottom),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: KiraColors.primary500)),
      error: (err, stack) => Center(
        child: Text('Error loading emissions: $err', style: KiraTypography.bodyMedium),
      ),
    );
  }
  
  /// Hero section with emissions total - matching dashboard layout
  Widget _buildHeroSection(double emissions, int change) {
    return Column(
      children: [
        SizedBox(height: KiraSpacing.heroTop),
        
        // Label - bigger, matching dashboard
        Text(
          'TOTAL CO₂ EMITTED',
          style: KiraTypography.h4.copyWith(
            letterSpacing: 2,
            color: KiraColors.textSecondary,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Big number in kg - matching dashboard
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              emissions.toStringAsFixed(0),
              style: KiraTypography.hero,
            ),
            const SizedBox(width: 6),
            Text(
              'kg',
              style: KiraTypography.h3.copyWith(
                color: KiraColors.textTertiary,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Period selector - moved up, matching dashboard
        PeriodSelector(
          selected: _period,
          onChanged: (p) => setState(() => _period = p),
        ),
        
        SizedBox(height: KiraSpacing.heroBottom),
      ],
    );
  }
  
  /// Scope selector with stats
  Widget _buildScopeSelector(
    Map<String, dynamic> currentScope,
    List<Receipt> scopeReceipts,
    double totalEmissions,
    double scopeEmissions,
  ) {
    final percentage = totalEmissions > 0 ? (scopeEmissions / totalEmissions * 100).round() : 0;
    
    return KiraCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Scope buttons
          Row(
            children: _scopeInfo.map((scope) {
              final isActive = _selectedScope == scope['id'];
              final color = scope['color'] as Color;
              
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedScope = scope['id'] as int),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: isActive ? color.withOpacity(0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive ? color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          scope['icon'] as IconData,
                          size: 14,
                          color: isActive ? color : KiraColors.textTertiary,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          scope['name'] as String,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isActive ? color : KiraColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 10),
          
          // Divider
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.06),
          ),
          
          const SizedBox(height: 10),
          
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('${scopeEmissions.toStringAsFixed(0)} kg', 'CO₂e', currentScope['color'] as Color),
              _buildStatItem('$percentage%', 'of total', null),
              _buildStatItem('${scopeReceipts.length}', 'sources', null),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String value, String label, Color? valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: KiraTypography.statValue.copyWith(
            color: valueColor ?? KiraColors.textPrimary,
          ),
        ),
        Text(label, style: KiraTypography.micro),
      ],
    );
  }
  
  /// Receipt items for selected scope
  Widget _buildReceiptItems(Map<String, dynamic> scope, List<Receipt> receipts) {
    if (receipts.isEmpty) {
      return KiraCard(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No ${scope['name']} receipts yet',
            style: KiraTypography.bodyMedium.copyWith(color: KiraColors.textSecondary),
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${scope['name']} SOURCES', style: KiraTypography.sectionTitle),
        const SizedBox(height: 12),
        ...receipts.map((receipt) => _buildReceiptItem(receipt, scope['color'] as Color)),
      ],
    );
  }
  
  Widget _buildReceiptItem(Receipt receipt, Color scopeColor) {
    // Get icon based on category
    IconData icon = Icons.receipt;
    switch (receipt.category.toLowerCase()) {
      case 'utilities':
        icon = Icons.bolt;
        break;
      case 'transport':
        icon = Icons.directions_car;
        break;
      case 'materials':
        icon = Icons.factory;
        break;
      case 'waste':
        icon = Icons.delete_outline;
        break;
      case 'office':
        icon = Icons.business_center;
        break;
      case 'travel':
        icon = Icons.flight;
        break;
      default:
        icon = Icons.receipt_long;
        break;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => ItemDetailModal(
              receipt: receipt,
              type: DetailType.emission,
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: KiraCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Icon
              Icon(icon, size: 20, color: scopeColor),
              const SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(receipt.vendor, style: KiraTypography.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${receipt.lineItems.length} item${receipt.lineItems.length != 1 ? 's' : ''}',
                      style: KiraTypography.labelSmall,
                    ),
                  ],
                ),
              ),
              
              // Carbon value
              Text(
                '${(receipt.co2Kg).toStringAsFixed(0)} kg',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: scopeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Tip card
  Widget _buildTipCard() {
    return KiraCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline,
            size: 18,
            color: KiraColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Switch to TNB Green to reduce Scope 2 emissions by up to 100%.',
              style: KiraTypography.bodySmall.copyWith(
                color: KiraColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
