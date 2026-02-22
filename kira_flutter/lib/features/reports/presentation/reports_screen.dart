/// Reports Screen
/// 
/// Carbon report generation with company profile, filters, receipt selection,
/// and PDF/Excel export. Matches the reference design UI.
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../shared/widgets/kira_card.dart';
import '../../../shared/widgets/report_export_notifier.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/receipt_providers.dart';
import '../../../data/models/receipt.dart';
import '../../../data/services/report_service.dart';
import 'export_format_sheet.dart';

/// Reports screen implementation
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _timeFilter = 'All Time';
  String _scopeFilter = 'All Scopes';
  final Set<String> _selectedIds = {};

  final _reportService = ReportService();

  // ── Filter receipts by time & scope ──────────────────
  List<Receipt> _applyFilters(List<Receipt> receipts) {
    final now = DateTime.now();
    var filtered = receipts;

    // Time filter
    switch (_timeFilter) {
      case 'This Month':
        filtered = filtered.where((r) =>
          r.date.year == now.year && r.date.month == now.month).toList();
        break;
      case 'This Quarter':
        final qStart = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1);
        filtered = filtered.where((r) => r.date.isAfter(qStart.subtract(const Duration(days: 1)))).toList();
        break;
      case '${2026}':
      case '${2025}':
        final year = int.tryParse(_timeFilter);
        if (year != null) {
          filtered = filtered.where((r) => r.date.year == year).toList();
        }
        break;
      case 'All Time':
      default:
        break;
    }

    // Scope filter
    switch (_scopeFilter) {
      case 'Scope 1':
        filtered = filtered.where((r) => r.scope == 1).toList();
        break;
      case 'Scope 2':
        filtered = filtered.where((r) => r.scope == 2).toList();
        break;
      case 'Scope 3':
        filtered = filtered.where((r) => r.scope == 3).toList();
        break;
      default:
        break;
    }

    return filtered;
  }

  // ── Export handler ──────────────────────────────────
  Future<void> _handleExport(List<Receipt> selectedReceipts, dynamic profile) async {
    if (selectedReceipts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one receipt to export')),
      );
      return;
    }

    final formats = await showExportFormatSheet(context);
    if (formats == null || formats.isEmpty || !mounted) return;

    setState(() => reportExportingNotifier.value = true);

    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final exported = <String>[];

      if (formats.contains('pdf')) {
        final pdfBytes = await _reportService.generatePdfReport(
          profile: profile,
          receipts: selectedReceipts,
          periodLabel: _timeFilter,
        );
        if (!mounted) return;
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'Kira_GHG_Report_$ts.pdf',
        );
        exported.add('PDF');
      }

      if (formats.contains('excel')) {
        final xlsxBytes = _reportService.generateExcelReport(
          profile: profile,
          receipts: selectedReceipts,
          periodLabel: _timeFilter,
        );
        if (!mounted) return;
        await Printing.sharePdf(
          bytes: xlsxBytes,
          filename: 'Kira_GHG_Report_$ts.xlsx',
        );
        exported.add('Excel');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${exported.join(' & ')} report${exported.length > 1 ? 's' : ''} generated!'),
            backgroundColor: KiraColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: KiraColors.primary600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => reportExportingNotifier.value = false);
    }
  }

  @override
  void dispose() {
    // Unregister from the global notifier when leaving this screen
    reportExportNotifier.value = null;
    reportExportingNotifier.value = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileStreamProvider);
    final receiptsAsync = ref.watch(receiptsStreamProvider);
    
    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const Center(child: Text('No profile found'));
        }
        
        return receiptsAsync.when(
          data: (allReceipts) {
            final filteredReceipts = _applyFilters(allReceipts);
            
            // Auto-clean selected IDs that no longer exist
            _selectedIds.removeWhere((id) =>
              !filteredReceipts.any((r) => r.id == id));
            
            final selectedReceipts = filteredReceipts
                .where((r) => _selectedIds.contains(r.id))
                .toList();
            
            final selectedCO2 = selectedReceipts.fold(0.0, (s, r) => s + r.co2Kg);
            
            // Register export callback with the global notifier
            // so the shell-level button can trigger it
            if (filteredReceipts.isNotEmpty && _selectedIds.isNotEmpty) {
            reportExportNotifier.value = () => _handleExport(selectedReceipts, profile);
            } else {
              reportExportNotifier.value = null;
            }
            
            return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      
                      // Title
                      Text('Carbon Report', style: KiraTypography.h3),
                      const SizedBox(height: 6),
                      Text(
                        'Generate GHG Protocol compliant report',
                        style: KiraTypography.bodySmall.copyWith(
                          color: KiraColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      
                      // Company Profile Card
                      _buildProfileCard(profile),
                      const SizedBox(height: 14),
                      
                      // Filter Row
                      _buildFilterRow(),
                      const SizedBox(height: 14),
                      
                      // Selection Summary
                      _buildSelectionSummary(
                        selectedCount: _selectedIds.length,
                        totalCO2: selectedCO2,
                        filteredReceipts: filteredReceipts,
                      ),
                      const SizedBox(height: 18),
                      
                      // Receipt List
                      if (filteredReceipts.isEmpty)
                        _buildEmptyState()
                      else ...[
                        Text('RECEIPTS', style: KiraTypography.sectionTitle),
                        const SizedBox(height: 10),
                        ...filteredReceipts.map((r) => _buildReceiptCard(r)),
                      ],
                      
                      const SizedBox(height: 90), // space for nav
                    ],
                  ),
                );
              },
          loading: () => const Center(child: CircularProgressIndicator(color: KiraColors.primary500)),
          error: (err, stack) => Center(child: Text('Error: $err')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  // ═══════════════════════════════════════════════════
  // UI COMPONENTS
  // ═══════════════════════════════════════════════════

  /// Company profile card
  Widget _buildProfileCard(dynamic profile) {
    return GestureDetector(
      onTap: () => _showEditProfileDialog(profile),
      child: KiraCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: KiraColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.business_outlined,
                size: 22,
                color: KiraColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.companyName,
                    style: KiraTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${profile.industry ?? 'No industry'} • ${profile.companySize ?? 'Unknown size'}',
                    style: KiraTypography.labelSmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: KiraColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  /// Filter row with time and scope dropdowns
  Widget _buildFilterRow() {
    return Row(
      children: [
        Expanded(child: _buildFilterChip(
          icon: Icons.calendar_today,
          value: _timeFilter,
          items: ['All Time', '2026', '2025', 'This Month', 'This Quarter'],
          onChanged: (v) => setState(() {
            _timeFilter = v!;
            _selectedIds.clear(); // reset selection on filter change
          }),
        )),
        const SizedBox(width: 10),
        Expanded(child: _buildFilterChip(
          icon: Icons.tune,
          value: _scopeFilter,
          items: ['All Scopes', 'Scope 1', 'Scope 2', 'Scope 3'],
          onChanged: (v) => setState(() {
            _scopeFilter = v!;
            _selectedIds.clear();
          }),
        )),
      ],
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: KiraColors.textTertiary, size: 20),
          dropdownColor: KiraColors.surface,
          style: KiraTypography.bodySmall.copyWith(fontSize: 13),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Row(
              children: [
                if (item == value) Icon(icon, size: 16, color: KiraColors.primary400),
                if (item == value) const SizedBox(width: 8),
                Text(item, style: const TextStyle(fontSize: 13)),
              ],
            ),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// Selection summary card
  Widget _buildSelectionSummary({
    required int selectedCount,
    required double totalCO2,
    required List<Receipt> filteredReceipts,
  }) {
    final tonnes = totalCO2 / 1000;
    final allSelected = _selectedIds.length == filteredReceipts.length && filteredReceipts.isNotEmpty;
    return KiraCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$selectedCount receipt${selectedCount == 1 ? '' : 's'} selected',
                  style: KiraTypography.bodySmall.copyWith(
                    color: KiraColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: KiraTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    children: [
                      TextSpan(text: '${tonnes.toStringAsFixed(1)}t '),
                      TextSpan(
                        text: 'CO\u2082e total',
                        style: KiraTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.normal,
                          color: KiraColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Select All / Deselect All
          TextButton(
            onPressed: () {
              setState(() {
                if (allSelected) {
                  _selectedIds.clear();
                } else {
                  _selectedIds.addAll(filteredReceipts.map((r) => r.id));
                }
              });
            },
            child: Text(
              allSelected ? 'Deselect' : 'Select all',
              style: TextStyle(
                color: KiraColors.primary400,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Individual receipt card with checkbox
  Widget _buildReceiptCard(Receipt receipt) {

    final isSelected = _selectedIds.contains(receipt.id);
    final scope = receipt.scope;
    final co2 = receipt.co2Kg;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedIds.remove(receipt.id);
            } else {
              _selectedIds.add(receipt.id);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? KiraColors.primary500.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? KiraColors.primary500.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              // Checkbox
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected
                      ? KiraColors.primary500
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? KiraColors.primary500
                        : Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 12),

              // Category icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _getScopeColor(scope).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getCategoryIcon(receipt.category),
                  size: 18,
                  color: _getScopeColor(scope),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.name,
                      style: KiraTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'RM ${receipt.total.toStringAsFixed(0)}',
                      style: KiraTypography.labelSmall,
                    ),
                  ],
                ),
              ),

              // CO2
              Text(
                '${co2.toStringAsFixed(0)} kg',
                style: KiraTypography.bodyMedium.copyWith(
                  color: KiraColors.textAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Empty state
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.description_outlined, size: 48, color: KiraColors.textTertiary),
            const SizedBox(height: 16),
            Text('No receipts found',
              style: KiraTypography.bodyMedium.copyWith(color: KiraColors.textSecondary)),
            const SizedBox(height: 8),
            Text('Try adjusting your filters or upload receipts first',
              style: KiraTypography.bodySmall.copyWith(color: KiraColors.textTertiary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'electricity': case 'utilities': return Icons.bolt;
      case 'transport': return Icons.directions_car;
      case 'materials': return Icons.factory;
      case 'waste': return Icons.delete_outline;
      case 'office': return Icons.business_center;
      case 'travel': return Icons.flight;
      default: return Icons.receipt_long;
    }
  }

  Color _getScopeColor(int scope) {
    switch (scope) {
      case 1: return KiraColors.scope1;
      case 2: return KiraColors.scope2;
      case 3: return KiraColors.scope3;
      default: return KiraColors.textSecondary;
    }
  }

  // ═══════════════════════════════════════════════════
  // EDIT PROFILE DIALOG (unchanged from before)
  // ═══════════════════════════════════════════════════

  void _showEditProfileDialog(dynamic profile) {
    final formKey = GlobalKey<FormState>();
    final companyNameController = TextEditingController(text: profile.companyName);
    final regNumberController = TextEditingController(text: profile.regNumber ?? '');
    final addressController = TextEditingController(text: profile.companyAddress ?? '');
    String? industry = profile.industry;
    String? companySize = profile.companySize;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  KiraColors.success.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: KiraColors.success.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                ),
                BoxShadow(
                  color: KiraColors.success.withValues(alpha: 0.1),
                  blurRadius: 40,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Edit Company Profile',
                            style: KiraTypography.h3.copyWith(fontSize: 18)),
                          const SizedBox(height: 16),
                          
                          _buildTextField(
                            controller: companyNameController,
                            label: 'Company Name *',
                            validator: (v) => v?.isEmpty == true ? 'Required' : null,
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            controller: regNumberController,
                            label: 'SSM Registration No.',
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            controller: addressController,
                            label: 'Company Address',
                            maxLines: 2,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdown(
                            value: industry,
                            label: 'Industry',
                            items: [
                              'Manufacturing', 'Technology', 'Retail',
                              'Services', 'Hospitality', 'Healthcare',
                              'Education', 'Construction', 'Other',
                            ],
                            onChanged: (v) => setState(() => industry = v),
                          ),
                          const SizedBox(height: 10),
                          _buildDropdown(
                            value: companySize,
                            label: 'Company Size',
                            items: [
                              '1-10 employees', '11-50 employees',
                              '51-200 employees', '201-500 employees',
                              '500+ employees',
                            ],
                            onChanged: (v) => setState(() => companySize = v),
                          ),
                          const SizedBox(height: 20),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: KiraColors.primary500.withValues(alpha: 0.5),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : () async {
                                    if (!formKey.currentState!.validate()) return;
                                    setState(() => isLoading = true);
                                    try {
                                      final updated = profile.copyWith(
                                        companyName: companyNameController.text,
                                        regNumber: regNumberController.text.isEmpty ? null : regNumberController.text,
                                        companyAddress: addressController.text.isEmpty ? null : addressController.text,
                                        industry: industry,
                                        companySize: companySize,
                                        updatedAt: DateTime.now(),
                                      );
                                      final service = ref.read(userProfileServiceProvider);
                                      await service.saveProfile(updated);
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Profile updated!')),
                                        );
                                      }
                                    } catch (e) {
                                      setState(() => isLoading = false);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: KiraColors.primary500,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: isLoading
                                    ? const SizedBox(
                                        width: 14, height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(Colors.white),
                                        ),
                                      )
                                    : const Text('Save', style: TextStyle(fontSize: 13)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: KiraColors.primary500, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      style: const TextStyle(fontSize: 13, color: KiraColors.text900),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item, style: const TextStyle(fontSize: 13)),
      )).toList(),
      onChanged: onChanged,
    );
  }
}
