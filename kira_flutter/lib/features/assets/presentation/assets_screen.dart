/// Assets Screen (GITA)
/// 
/// GITA tax savings display with verified green assets list.
/// Matches React Assets.jsx.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../shared/widgets/kira_card.dart';
import '../../../shared/widgets/kira_badge.dart';
import '../../../shared/widgets/period_selector.dart';
import '../../../shared/widgets/item_detail_modal.dart';
import '../../../providers/receipt_providers.dart';
import '../../../data/models/receipt.dart';
import '../../../data/models/line_item.dart';

/// Assets screen implementation
class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  String _period = 'Year';
  
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

  @override
  Widget build(BuildContext context) {
    final receiptsAsync = ref.watch(receiptsStreamProvider);
    
    return receiptsAsync.when(
      data: (allReceipts) {
        // Apply period filter, then filter for GITA-eligible
        final periodReceipts = _filterByPeriod(allReceipts);
        final gitaReceipts = periodReceipts.where((r) => r.gitaEligible).toList();
        final totalSavings = gitaReceipts.fold(0.0, (sum, r) => sum + r.gitaAllowance);
        
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Section
              _buildHeroSection(totalSavings.toInt(), 0),
              
              const SizedBox(height: 24),
              
              // GITA Assets List or Empty State
              if (gitaReceipts.isEmpty)
                _buildEmptyState()
              else
                _buildGitaAssetsList(gitaReceipts),
              
              const SizedBox(height: 20),
              
              // Info Card
              _buildInfoCard(),
              
              const SizedBox(height: KiraSpacing.screenBottom),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.eco_outlined,
            size: 64,
            color: KiraColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No verified green assets yet',
            style: KiraTypography.bodyMedium.copyWith(
              color: KiraColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload receipts for GITA-eligible purchases',
            style: KiraTypography.bodySmall.copyWith(
              color: KiraColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Hero section with tax savings - matching dashboard layout
  Widget _buildHeroSection(int savings, int change) {
    return Column(
      children: [
        SizedBox(height: KiraSpacing.heroTop),
        
        // Label - bigger, matching dashboard
        Text(
          'TOTAL TAX SAVED',
          style: KiraTypography.h4.copyWith(
            letterSpacing: 2,
            color: KiraColors.textSecondary,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Big number - matching dashboard
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'RM ',
              style: KiraTypography.h3.copyWith(
                color: KiraColors.textTertiary,
              ),
            ),
            Text(
              _formatNumber(savings),
              style: KiraTypography.hero,
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
  
  Widget _buildGitaAssetsList(List<Receipt> receipts) {
    // 1. Flatten into (LineItem, Receipt) pairs
    final List<({LineItem item, Receipt receipt})> gitaItems = [];
    
    for (var receipt in receipts) {
      for (var item in receipt.lineItems) {
        if (item.gitaEligible) {
          gitaItems.add((item: item, receipt: receipt));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GITA Eligible Assets',
          style: KiraTypography.h4,
        ),
        const SizedBox(height: 12),
        ...gitaItems.map((entry) {
          final item = entry.item;
          final receipt = entry.receipt;
          final allowance = item.gitaAllowance ?? 0.0;
          
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
                    type: DetailType.gita,
                    focusedItem: item,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: KiraCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    // Top Row: Icon, Title, Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon
                        Icon(
                          _getCategoryIcon(item.gitaCategory ?? 'utilities'),
                          color: KiraColors.primary400, // Light green icon
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        
                        // Title & Vendor
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: KiraTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                receipt.vendor,
                                style: KiraTypography.bodySmall.copyWith(
                                  color: KiraColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Badge
                        KiraBadge.success(
                           label: 'GITA',
                           icon: Icons.verified,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Bottom Row: Cost & Saved (Darker inner box)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2), // Darker inner box
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Cost
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cost',
                                style: KiraTypography.labelSmall.copyWith(color: KiraColors.textTertiary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'RM ${_formatNumber(item.price.toInt())}',
                                style: KiraTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          
                          // Saved
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Saved',
                                style: KiraTypography.labelSmall.copyWith(color: KiraColors.textTertiary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'RM ${_formatNumber(allowance.toInt())}',
                                style: KiraTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: KiraColors.primary300, // Light green text for savings
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // Helper for icons (duplicate of modal one, good to have here too)
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
  
  /// Info card about GITA
  Widget _buildInfoCard() {
    return KiraCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            size: 18,
            color: KiraColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: KiraTypography.bodySmall.copyWith(
                  color: KiraColors.textSecondary,
                ),
                children: const [
                  TextSpan(
                    text: 'GITA: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: '100% of asset cost can offset up to 70% of your statutory income.',
                  ),
                ],
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
