/// Dashboard Screen
/// 
/// Main home screen showing emissions overview, scope breakdown,
/// and trend chart. Uses real receipt data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../shared/widgets/kira_card.dart';
import '../../../shared/widgets/period_selector.dart';
import '../../../providers/receipt_providers.dart';
import '../../../data/models/receipt.dart';

/// Dashboard screen implementation
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
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
  
  /// Calculate monthly trend data from receipts (last 6 months, dynamic)
  List<Map<String, dynamic>> _calculateMonthlyTrend(List<Receipt> receipts) {
    final now = DateTime.now();
    final months = <String>[];
    final monthKeys = <String>[];
    
    // Generate last 6 months dynamically
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      months.add(_getMonthName(date.month - 1));
      monthKeys.add('${date.year}-${date.month}');
    }
    
    final monthData = <String, double>{};
    for (var key in monthKeys) {
      monthData[key] = 0;
    }
    
    // Sum up CO2 by month
    for (final receipt in receipts) {
      final key = '${receipt.date.year}-${receipt.date.month}';
      if (monthData.containsKey(key)) {
        monthData[key] = (monthData[key] ?? 0) + receipt.co2Kg;
      }
    }
    
    return List.generate(months.length, (i) => {
      'month': months[i],
      'value': monthData[monthKeys[i]] ?? 0.0,
    });
  }
  
  String _getMonthName(int index) {
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return monthNames[index % 12];
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 Dashboard Build Called');
    final receiptsAsync = ref.watch(receiptsStreamProvider);
    
    return receiptsAsync.when(
      data: (allReceipts) {
        // Apply period filter
        final receipts = _filterByPeriod(allReceipts);
        print('📊 Dashboard Data: ${allReceipts.length} total, ${receipts.length} in $_period');
        
        // Calculate total CO2 in kg
        final totalCO2 = receipts.fold(0.0, (sum, r) => sum + r.co2Kg);
        
        // Calculate scope data from real receipts in kg
        final scope1Total = receipts.where((r) => r.scope == 1).fold(0.0, (sum, r) => sum + r.co2Kg);
        final scope2Total = receipts.where((r) => r.scope == 2).fold(0.0, (sum, r) => sum + r.co2Kg);
        final scope3Total = receipts.where((r) => r.scope == 3).fold(0.0, (sum, r) => sum + r.co2Kg);
        
        final scopeData = [
          if (scope1Total > 0) {'name': 'Scope 1', 'value': scope1Total, 'color': KiraColors.scope1, 'label': 'Direct'},
          if (scope2Total > 0) {'name': 'Scope 2', 'value': scope2Total, 'color': KiraColors.scope2, 'label': 'Electricity'},
          if (scope3Total > 0) {'name': 'Scope 3', 'value': scope3Total, 'color': KiraColors.scope3, 'label': 'Supply Chain'},
        ];
        
        final totalScope = scope1Total + scope2Total + scope3Total;
        final trendData = _calculateMonthlyTrend(allReceipts); // Trend always shows all data
        
        // Calculate real GITA savings
        final gitaSavings = receipts.fold(0.0, (sum, r) => sum + r.gitaAllowance);
        
        // Calculate carbon tax: CO2 in kg → tonnes, then * RM 15/tonne
        final carbonTax = (totalCO2 / 1000) * 15;
    
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Section
              _buildHeroSection(totalCO2),
              
              const SizedBox(height: 24),
              
              // Scope Breakdown
              _buildScopeBreakdown(totalScope, scopeData),
              
              const SizedBox(height: 20),
              
              // Trend Chart
              _buildTrendChart(trendData),
              
              const SizedBox(height: 20),
              
              // Key Metrics
              _buildKeyMetrics(receipts.length, gitaSavings, carbonTax),
              
              const SizedBox(height: KiraSpacing.screenBottom),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
  
  /// Hero section with large emissions number
  Widget _buildHeroSection(double emissions) {
    return Column(
      children: [
        SizedBox(height: KiraSpacing.heroTop),
        
        // Label - bigger
        Text(
          'TOTAL CO₂ EMITTED',
          style: KiraTypography.h4.copyWith(
            letterSpacing: 2,
            color: KiraColors.textSecondary,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Big number in kg - slightly smaller
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
        
        // Period selector - moved up
        PeriodSelector(
          selected: _period,
          onChanged: (p) => setState(() => _period = p),
        ),
        
        SizedBox(height: KiraSpacing.heroBottom),
      ],
    );
  }
  
  /// Scope breakdown with pie chart
  Widget _buildScopeBreakdown(double total, List<Map<String, dynamic>> scopeData) {
    return KiraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SCOPE BREAKDOWN',
            style: KiraTypography.caption,
          ),
          const SizedBox(height: 16),
          
          if (scopeData.isEmpty) 
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No emissions data for this period',
                  style: KiraTypography.bodySmall.copyWith(
                    color: KiraColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                // Pie chart
                SizedBox(
                  width: 100,
                  height: 100,
                  child: PieChart(
                    PieChartData(
                      sections: scopeData.map((scope) {
                        final percentage = (scope['value'] as double) / total * 100;
                        return PieChartSectionData(
                          value: scope['value'] as double,
                          color: scope['color'] as Color,
                          radius: 16,
                          title: '${percentage.toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                
                // Legend
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: scopeData.map((scope) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(
                                color: scope['color'] as Color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              scope['label'] as String,
                              style: KiraTypography.labelSmall,
                            ),
                            const Spacer(),
                            Text(
                              '${(scope['value'] as double).toStringAsFixed(0)} kg',
                              style: KiraTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  /// Monthly trend line chart
  Widget _buildTrendChart(List<Map<String, dynamic>> trendData) {
    final maxValue = trendData.fold(0.0, (max, d) {
      final v = d['value'] as double;
      return v > max ? v : max;
    });
    
    return KiraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MONTHLY TREND',
            style: KiraTypography.caption,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue > 0 ? maxValue / 3 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < trendData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              trendData[idx]['month'] as String,
                              style: KiraTypography.micro,
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: maxValue > 0 ? maxValue * 1.25 : 10,
                lineBarsData: [
                  LineChartBarData(
                    spots: trendData.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value['value'] as double);
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: KiraColors.primary500,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: KiraColors.primary500,
                          strokeWidth: 1.5,
                          strokeColor: KiraColors.primary400,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          KiraColors.primary500.withOpacity(0.25),
                          KiraColors.primary500.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Key metrics grid
  Widget _buildKeyMetrics(int receiptCount, double gitaSavings, double carbonTax) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KEY METRICS',
          style: KiraTypography.sectionTitle,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMetricCard('GITA Saved', 'RM ${gitaSavings.toStringAsFixed(0)}', Icons.eco)),
            const SizedBox(width: 10),
            Expanded(child: _buildMetricCard('Carbon Tax', 'RM ${carbonTax.toStringAsFixed(2)}', Icons.account_balance)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildMetricCard('Receipts', '$receiptCount', Icons.receipt_long)),
            const SizedBox(width: 10),
            Expanded(child: _buildMetricCard('Grid Factor', '0.538', Icons.bolt)),
          ],
        ),
      ],
    );
  }
  
  Widget _buildMetricCard(String label, String value, IconData icon) {
    return KiraCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: KiraColors.primary500.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: KiraColors.primary500),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KiraTypography.labelSmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: KiraTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
