/// Export Format Sheet
///
/// Bottom sheet modal for choosing PDF, Excel, or both.
library;

import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';

/// Shows a bottom sheet for selecting export format(s).
/// Returns a Set of selected formats: {'pdf'}, {'excel'}, or {'pdf', 'excel'}.
Future<Set<String>?> showExportFormatSheet(BuildContext context) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _ExportFormatBody(),
  );
}

class _ExportFormatBody extends StatefulWidget {
  const _ExportFormatBody();

  @override
  State<_ExportFormatBody> createState() => _ExportFormatBodyState();
}

class _ExportFormatBodyState extends State<_ExportFormatBody> {
  bool _pdf = true;
  bool _excel = false;

  @override
  Widget build(BuildContext context) {
    final hasSelection = _pdf || _excel;

    final bottomPad = MediaQuery.of(context).padding.bottom + 100; // nav + FABs

    return Container(
      decoration: BoxDecoration(
        color: KiraColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          Text('Export Report', style: KiraTypography.h3.copyWith(fontSize: 18)),
          const SizedBox(height: 6),
          Text('Select one or both formats',
            style: KiraTypography.bodySmall.copyWith(color: KiraColors.textTertiary)),
          const SizedBox(height: 20),

          // PDF toggle
          _FormatToggle(
            icon: Icons.picture_as_pdf_outlined,
            title: 'PDF Report',
            subtitle: 'GHG Protocol formatted, ready to share',
            color: KiraColors.primary500,
            selected: _pdf,
            onToggle: () => setState(() => _pdf = !_pdf),
          ),
          const SizedBox(height: 10),

          // Excel toggle
          _FormatToggle(
            icon: Icons.table_chart_outlined,
            title: 'Excel Spreadsheet',
            subtitle: 'Raw data with Summary, Detail & GITA sheets',
            color: KiraColors.success,
            selected: _excel,
            onToggle: () => setState(() => _excel = !_excel),
          ),
          const SizedBox(height: 22),

          // Generate button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: hasSelection
                  ? () {
                      final result = <String>{};
                      if (_pdf) result.add('pdf');
                      if (_excel) result.add('excel');
                      Navigator.pop(context, result);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: KiraColors.primary500,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                hasSelection
                    ? 'Generate ${_pdf && _excel ? 'Both' : _pdf ? 'PDF' : 'Excel'}'
                    : 'Select a format',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onToggle;

  const _FormatToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: 0.08),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: KiraTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                    const SizedBox(height: 2),
                    Text(subtitle, style: KiraTypography.bodySmall.copyWith(
                      color: KiraColors.textTertiary, fontSize: 12,
                    )),
                  ],
                ),
              ),
              // Checkbox
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: selected ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: selected ? color : Colors.white.withValues(alpha: 0.20),
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
