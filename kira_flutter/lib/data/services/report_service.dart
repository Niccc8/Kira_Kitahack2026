/// Report Generation Service
///
/// Generates professional GHG Protocol-compliant Carbon Reports in PDF and
/// Excel formats.  Both outputs share an identical layout:
///
///   1. Company header
///   2. Emissions summary (totals + scope breakdown)
///   3. Scope 1 / 2 / 3 receipt detail tables
///   4. GITA Tax Savings section
///   5. Footer
///
/// PDF  → white-background, professional black-on-white styling
/// Excel → single sheet with coloured section headers, merged cells, borders
library;

import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xl;
import '../models/receipt.dart';
import '../models/user_profile.dart';

// ─── Colour constants (shared) ──────────────────────────────────────────
const _kGreen   = '#1B7A3D';
const _kGreenLt = '#E8F5E9';
const _kScope1   = '#D32F2F';
const _kScope1Lt = '#FFEBEE';
const _kScope2   = '#F57C00';
const _kScope2Lt = '#FFF3E0';
const _kScope3   = '#1565C0';
const _kScope3Lt = '#E3F2FD';
const _kGrey     = '#F5F5F5';
const _kGreyBdr  = '#E0E0E0';
const _kDarkText = '#212121';
const _kMedText  = '#616161';

class ReportService {
  final _rm = NumberFormat.currency(locale: 'en_MY', symbol: 'RM ', decimalDigits: 2);
  final _n2 = NumberFormat('#,##0.00');
  final _n1 = NumberFormat('#,##0.0');

  // ════════════════════════════════════════════════════════════════════════
  // DATA HELPERS
  // ════════════════════════════════════════════════════════════════════════

  double _scopeCO2(List<Receipt> receipts, int scope) {
    double total = 0;
    for (final r in receipts) {
      for (final item in r.lineItems) {
        if (item.scope == scope) total += item.co2Kg;
      }
    }
    return total;
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _dateFmt(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  /// Build list of items for a given scope across all receipts
  List<_ItemRow> _itemsForScope(List<Receipt> receipts, int scope) {
    final rows = <_ItemRow>[];
    for (final r in receipts) {
      for (final item in r.lineItems.where((i) => i.scope == scope)) {
        rows.add(_ItemRow(
          date: _dateFmt(r.date),
          vendor: r.vendor,
          item: item.name,
          category: _cap(item.category),
          qty: '${_n2.format(item.quantity)} ${item.unit}',
          price: _rm.format(item.price),
          co2Kg: _n1.format(item.co2Kg),
          co2T: _n2.format(item.co2Kg / 1000),
        ));
      }
    }
    return rows;
  }

  /// Build GITA-eligible item rows
  List<_GitaRow> _gitaItems(List<Receipt> receipts) {
    final rows = <_GitaRow>[];
    for (final r in receipts) {
      for (final item in r.lineItems.where((i) => i.gitaEligible)) {
        rows.add(_GitaRow(
          date: _dateFmt(r.date),
          vendor: r.vendor,
          item: item.name,
          tier: item.gitaTier?.toString() ?? '-',
          cat: item.gitaCategory ?? '-',
          price: _rm.format(item.price),
          savings: _rm.format(item.gitaSavings),
        ));
      }
    }
    return rows;
  }

  // ════════════════════════════════════════════════════════════════════════
  // PDF GENERATION
  // ════════════════════════════════════════════════════════════════════════

  Future<Uint8List> generatePdfReport({
    required UserProfile profile,
    required List<Receipt> receipts,
    required String periodLabel,
  }) async {
    final pdf = pw.Document();

    // aggregates
    final totalKg  = receipts.fold(0.0, (s, r) => s + r.co2Kg);
    final totalT   = totalKg / 1000;
    final totalRM  = receipts.fold(0.0, (s, r) => s + r.total);
    final s1Kg = _scopeCO2(receipts, 1);
    final s2Kg = _scopeCO2(receipts, 2);
    final s3Kg = _scopeCO2(receipts, 3);
    final s1Items = _itemsForScope(receipts, 1);
    final s2Items = _itemsForScope(receipts, 2);
    final s3Items = _itemsForScope(receipts, 3);
    final gitaRows = _gitaItems(receipts);
    final totalGita = receipts.where((r) => r.gitaEligible).fold(0.0, (s, r) => s + r.gitaAllowance);
    final carbonTax = totalT * 15;

    // PDF colours
    final green    = PdfColor.fromHex(_kGreen);
    final greenLt  = PdfColor.fromHex(_kGreenLt);
    final scope1   = PdfColor.fromHex(_kScope1);
    final scope1Lt = PdfColor.fromHex(_kScope1Lt);
    final scope2   = PdfColor.fromHex(_kScope2);
    final scope2Lt = PdfColor.fromHex(_kScope2Lt);
    final scope3   = PdfColor.fromHex(_kScope3);
    final scope3Lt = PdfColor.fromHex(_kScope3Lt);
    final grey     = PdfColor.fromHex(_kGrey);
    final border   = PdfColor.fromHex(_kGreyBdr);
    final dark     = PdfColor.fromHex(_kDarkText);
    final med      = PdfColor.fromHex(_kMedText);

    final hdrStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    final cellStyle = pw.TextStyle(fontSize: 8, color: dark);
    final cellMed  = pw.TextStyle(fontSize: 8, color: med);
    final boldCell = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: dark);

    // ── Build pages ──
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (ctx) => _pdfHeader(profile, periodLabel, green, dark, med),
      footer: (ctx) => _pdfFooter(ctx, med),
      build: (ctx) => [
        // ═══ EMISSIONS SUMMARY ═══
        _pdfSectionTitle('EMISSIONS SUMMARY', green),
        pw.SizedBox(height: 6),

        // Summary table
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: border, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Table(
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: border, width: 0.5),
              verticalInside: pw.BorderSide(color: border, width: 0.5),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              _pdfTableHdr(['Metric', 'kg CO2e', 'Tonnes CO2e', '% of Total'], green),
              _pdfDataRow(['Total Emissions', _n1.format(totalKg), _n2.format(totalT), '100.0%'], greenLt, dark),
              _pdfDataRow(['Scope 1 - Direct', _n1.format(s1Kg), _n2.format(s1Kg/1000), _pct(s1Kg, totalKg)], PdfColors.white, dark),
              _pdfDataRow(['Scope 2 - Energy (Indirect)', _n1.format(s2Kg), _n2.format(s2Kg/1000), _pct(s2Kg, totalKg)], PdfColors.white, dark),
              _pdfDataRow(['Scope 3 - Other Indirect', _n1.format(s3Kg), _n2.format(s3Kg/1000), _pct(s3Kg, totalKg)], PdfColors.white, dark),
            ],
          ),
        ),
        pw.SizedBox(height: 8),

        // Financial bar
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(color: grey, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _pdfKV('Total Receipts', '${receipts.length}', dark, med),
              _pdfKV('Total Spend', _rm.format(totalRM), dark, med),
              _pdfKV('Est. Carbon Tax', _rm.format(carbonTax), dark, med),
              _pdfKV('GITA Savings', _rm.format(totalGita), green, med),
            ],
          ),
        ),
        pw.SizedBox(height: 16),

        // ═══ SCOPE 1 ═══
        if (s1Items.isNotEmpty) ...[
          _pdfSectionTitle('SCOPE 1 - DIRECT EMISSIONS', scope1),
          pw.SizedBox(height: 6),
          _pdfItemTable(s1Items, scope1, scope1Lt, border, hdrStyle, cellStyle, cellMed, boldCell),
          pw.SizedBox(height: 4),
          _pdfScopeTotalBar('Scope 1 Total', s1Kg, scope1, scope1Lt, dark),
          pw.SizedBox(height: 16),
        ],

        // ═══ SCOPE 2 ═══
        if (s2Items.isNotEmpty) ...[
          _pdfSectionTitle('SCOPE 2 - ENERGY INDIRECT EMISSIONS', scope2),
          pw.SizedBox(height: 6),
          _pdfItemTable(s2Items, scope2, scope2Lt, border, hdrStyle, cellStyle, cellMed, boldCell),
          pw.SizedBox(height: 4),
          _pdfScopeTotalBar('Scope 2 Total', s2Kg, scope2, scope2Lt, dark),
          pw.SizedBox(height: 16),
        ],

        // ═══ SCOPE 3 ═══
        if (s3Items.isNotEmpty) ...[
          _pdfSectionTitle('SCOPE 3 - OTHER INDIRECT EMISSIONS', scope3),
          pw.SizedBox(height: 6),
          _pdfItemTable(s3Items, scope3, scope3Lt, border, hdrStyle, cellStyle, cellMed, boldCell),
          pw.SizedBox(height: 4),
          _pdfScopeTotalBar('Scope 3 Total', s3Kg, scope3, scope3Lt, dark),
          pw.SizedBox(height: 16),
        ],

        // ═══ GITA TAX SAVINGS ═══
        if (gitaRows.isNotEmpty) ...[
          _pdfSectionTitle('GITA TAX SAVINGS', green),
          pw.SizedBox(height: 6),
          _pdfGitaTable(gitaRows, green, greenLt, border, hdrStyle, cellStyle, cellMed, boldCell),
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(color: greenLt, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total GITA Tax Savings', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: green)),
                pw.Text(_rm.format(totalGita), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: green)),
              ],
            ),
          ),
        ],
      ],
    ));

    return pdf.save();
  }

  // ── PDF widget helpers ──

  pw.Widget _pdfHeader(UserProfile profile, String period, PdfColor green, PdfColor dark, PdfColor med) {
    return pw.Column(children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('GHG EMISSIONS REPORT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: dark)),
            pw.SizedBox(height: 2),
            pw.Text('GHG Protocol Aligned | Generated by Kira', style: pw.TextStyle(fontSize: 8, color: med)),
          ]),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: pw.BoxDecoration(color: green, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text(period, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex(_kGrey),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(profile.companyName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: dark)),
            pw.SizedBox(height: 2),
            pw.Text(
              [profile.industry, profile.companySize].where((e) => e != null && e.isNotEmpty).join(' | '),
              style: pw.TextStyle(fontSize: 8, color: med),
            ),
          ])),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            if (profile.regNumber != null && profile.regNumber!.isNotEmpty)
              pw.Text('SSM: ${profile.regNumber}', style: pw.TextStyle(fontSize: 8, color: med)),
            if (profile.companyAddress != null && profile.companyAddress!.isNotEmpty)
              pw.Text(profile.companyAddress!, style: pw.TextStyle(fontSize: 8, color: med)),
          ]),
        ]),
      ),
      pw.SizedBox(height: 10),
      pw.Divider(color: PdfColor.fromHex(_kGreyBdr), thickness: 0.5),
      pw.SizedBox(height: 6),
    ]);
  }

  pw.Widget _pdfFooter(pw.Context ctx, PdfColor med) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Kira Carbon Tracker  |  kira26.web.app', style: pw.TextStyle(fontSize: 7, color: med)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 7, color: med)),
        pw.Text('Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}', style: pw.TextStyle(fontSize: 7, color: med)),
      ]),
    );
  }

  pw.Widget _pdfSectionTitle(String title, PdfColor accent) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(color: accent, borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 0.5)),
    );
  }

  pw.TableRow _pdfTableHdr(List<String> cells, PdfColor bg) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bg),
      children: cells.map((c) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Text(c, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      )).toList(),
    );
  }

  pw.TableRow _pdfDataRow(List<String> cells, PdfColor bg, PdfColor text) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bg),
      children: cells.asMap().entries.map((e) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Text(e.value, style: pw.TextStyle(
          fontSize: 8,
          color: text,
          fontWeight: e.key == 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
        )),
      )).toList(),
    );
  }

  pw.Widget _pdfKV(String label, String value, PdfColor valColor, PdfColor lblColor) {
    return pw.Column(children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 7, color: lblColor)),
      pw.SizedBox(height: 2),
      pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: valColor)),
    ]);
  }

  pw.Widget _pdfItemTable(
    List<_ItemRow> items, PdfColor accent, PdfColor accentLt, PdfColor border,
    pw.TextStyle hdrStyle, pw.TextStyle cellStyle, pw.TextStyle cellMed, pw.TextStyle boldCell,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: border, width: 0.5), borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Table(
        border: pw.TableBorder(horizontalInside: pw.BorderSide(color: border, width: 0.5)),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.5),  // Date
          1: const pw.FlexColumnWidth(2),    // Vendor
          2: const pw.FlexColumnWidth(2.5),  // Item
          3: const pw.FlexColumnWidth(1.5),  // Category
          4: const pw.FlexColumnWidth(1.5),  // Qty
          5: const pw.FlexColumnWidth(1.5),  // Price
          6: const pw.FlexColumnWidth(1.2),  // CO₂ kg
          7: const pw.FlexColumnWidth(1.2),  // CO₂ t
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: accent),
            children: ['Date', 'Vendor', 'Item', 'Category', 'Quantity', 'Price (RM)', 'CO2 (kg)', 'CO2 (t)']
              .map((h) => pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.Text(h, style: hdrStyle)))
              .toList(),
          ),
          for (var i = 0; i < items.length; i++)
            pw.TableRow(
              decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : accentLt),
              children: [
                _pc(items[i].date, cellMed),
                _pc(items[i].vendor, cellStyle),
                _pc(items[i].item, boldCell),
                _pc(items[i].category, cellStyle),
                _pc(items[i].qty, cellMed),
                _pc(items[i].price, cellStyle),
                _pc(items[i].co2Kg, cellStyle),
                _pc(items[i].co2T, cellMed),
              ],
            ),
        ],
      ),
    );
  }

  pw.Widget _pdfGitaTable(
    List<_GitaRow> items, PdfColor accent, PdfColor accentLt, PdfColor border,
    pw.TextStyle hdrStyle, pw.TextStyle cellStyle, pw.TextStyle cellMed, pw.TextStyle boldCell,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: border, width: 0.5), borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Table(
        border: pw.TableBorder(horizontalInside: pw.BorderSide(color: border, width: 0.5)),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.5),
          1: const pw.FlexColumnWidth(2),
          2: const pw.FlexColumnWidth(2.5),
          3: const pw.FlexColumnWidth(1),
          4: const pw.FlexColumnWidth(2),
          5: const pw.FlexColumnWidth(1.5),
          6: const pw.FlexColumnWidth(1.5),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: accent),
            children: ['Date', 'Vendor', 'Item', 'Tier', 'GITA Category', 'Price (RM)', 'Tax Savings']
              .map((h) => pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.Text(h, style: hdrStyle)))
              .toList(),
          ),
          for (var i = 0; i < items.length; i++)
            pw.TableRow(
              decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : accentLt),
              children: [
                _pc(items[i].date, cellMed),
                _pc(items[i].vendor, cellStyle),
                _pc(items[i].item, boldCell),
                _pc(items[i].tier, cellStyle),
                _pc(items[i].cat, cellStyle),
                _pc(items[i].price, cellStyle),
                _pc(items[i].savings, boldCell),
              ],
            ),
        ],
      ),
    );
  }

  pw.Widget _pdfScopeTotalBar(String label, double kg, PdfColor accent, PdfColor bg, PdfColor dark) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accent)),
        pw.Text('${_n1.format(kg)} kg  |  ${_n2.format(kg/1000)} tonnes CO2e',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: dark)),
      ]),
    );
  }

  pw.Padding _pc(String text, pw.TextStyle style) =>
    pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: pw.Text(text, style: style));

  String _pct(double part, double total) => total > 0 ? '${(part / total * 100).toStringAsFixed(1)}%' : '0.0%';

  // ════════════════════════════════════════════════════════════════════════
  // EXCEL GENERATION (SINGLE SHEET, FORMATTED)
  // ════════════════════════════════════════════════════════════════════════

  Uint8List generateExcelReport({
    required UserProfile profile,
    required List<Receipt> receipts,
    required String periodLabel,
  }) {
    final excel = xl.Excel.createExcel();
    final sheet = excel['GHG Report'];
    excel.setDefaultSheet('GHG Report');

    // ── Styles ──
    final greenHex = xl.ExcelColor.fromHexString('#FF1B7A3D');
    final greenLtHex = xl.ExcelColor.fromHexString('#FFE8F5E9');
    final s1Hex = xl.ExcelColor.fromHexString('#FFD32F2F');
    final s1LtHex = xl.ExcelColor.fromHexString('#FFFFEBEE');
    final s2Hex = xl.ExcelColor.fromHexString('#FFF57C00');
    final s2LtHex = xl.ExcelColor.fromHexString('#FFFFF3E0');
    final s3Hex = xl.ExcelColor.fromHexString('#FF1565C0');
    final s3LtHex = xl.ExcelColor.fromHexString('#FFE3F2FD');
    final whiteHex = xl.ExcelColor.fromHexString('#FFFFFFFF');
    final whiteFont = xl.ExcelColor.fromHexString('#FFFFFFFF');
    final darkFont = xl.ExcelColor.fromHexString('#FF212121');
    final medFont = xl.ExcelColor.fromHexString('#FF616161');

    xl.CellStyle sectionHdrStyle(xl.ExcelColor bg) => xl.CellStyle(
      backgroundColorHex: bg,
      fontColorHex: whiteFont,
      bold: true,
      fontSize: 12,
      horizontalAlign: xl.HorizontalAlign.Left,
    );

    xl.CellStyle tableHdrStyle(xl.ExcelColor bg) => xl.CellStyle(
      backgroundColorHex: bg,
      fontColorHex: whiteFont,
      bold: true,
      fontSize: 10,
      horizontalAlign: xl.HorizontalAlign.Center,
    );

    xl.CellStyle dataStyle({xl.ExcelColor? bg, bool bold = false}) => xl.CellStyle(
      backgroundColorHex: bg ?? whiteHex,
      fontColorHex: darkFont,
      bold: bold,
      fontSize: 10,
    );

    xl.CellStyle medStyle({xl.ExcelColor? bg}) => xl.CellStyle(
      backgroundColorHex: bg ?? whiteHex,
      fontColorHex: medFont,
      fontSize: 10,
    );

    xl.CellStyle totalStyle(xl.ExcelColor bg, xl.ExcelColor fg) => xl.CellStyle(
      backgroundColorHex: bg,
      fontColorHex: fg,
      bold: true,
      fontSize: 11,
    );

    int row = 0;

    // Helper to add a row of cells with styles
    void addRow(List<dynamic> values, {xl.CellStyle? style, List<xl.CellStyle?>? styles}) {
      for (int c = 0; c < values.length; c++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
        final v = values[c];
        if (v is double) {
          cell.value = xl.DoubleCellValue(v);
        } else if (v is int) {
          cell.value = xl.IntCellValue(v);
        } else {
          cell.value = xl.TextCellValue(v?.toString() ?? '');
        }
        if (styles != null && c < styles.length && styles[c] != null) {
          cell.cellStyle = styles[c]!;
        } else if (style != null) {
          cell.cellStyle = style;
        }
      }
      row++;
    }

    void blankRow() {
      row++;
    }

    // ── Set column widths ──
    sheet.setColumnWidth(0, 18);  // Date
    sheet.setColumnWidth(1, 28);  // Vendor
    sheet.setColumnWidth(2, 38);  // Item
    sheet.setColumnWidth(3, 22);  // Category / Metric
    sheet.setColumnWidth(4, 18);  // Qty / kg
    sheet.setColumnWidth(5, 18);  // Price / tonnes
    sheet.setColumnWidth(6, 18);  // CO₂ kg / %
    sheet.setColumnWidth(7, 18);  // CO₂ t

    // ════════════════════════════════════════════════════
    // HEADER
    // ════════════════════════════════════════════════════
    addRow(['GHG EMISSIONS REPORT'], style: xl.CellStyle(
      bold: true, fontSize: 16, fontColorHex: darkFont,
    ));
    addRow(['GHG Protocol Aligned • Generated by Kira'], style: xl.CellStyle(
      fontSize: 9, fontColorHex: medFont,
    ));
    blankRow();

    // Company info
    addRow(['Company:', profile.companyName], styles: [
      medStyle(), dataStyle(bold: true),
    ]);
    addRow(['Industry:', profile.industry ?? '-'], styles: [
      medStyle(), dataStyle(),
    ]);
    addRow(['Company Size:', profile.companySize ?? '-'], styles: [
      medStyle(), dataStyle(),
    ]);
    addRow(['SSM Reg. No.:', profile.regNumber ?? '-'], styles: [
      medStyle(), dataStyle(),
    ]);
    if (profile.companyAddress != null && profile.companyAddress!.isNotEmpty) {
      addRow(['Address:', profile.companyAddress!], styles: [
        medStyle(), dataStyle(),
      ]);
    }
    addRow(['Report Period:', periodLabel], styles: [
      medStyle(), dataStyle(bold: true),
    ]);
    addRow(['Generated:', DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())], styles: [
      medStyle(), dataStyle(),
    ]);
    blankRow();

    // ════════════════════════════════════════════════════
    // EMISSIONS SUMMARY
    // ════════════════════════════════════════════════════
    final totalKg = receipts.fold(0.0, (s, r) => s + r.co2Kg);
    final totalT  = totalKg / 1000;
    final totalRM = receipts.fold(0.0, (s, r) => s + r.total);
    final s1Kg = _scopeCO2(receipts, 1);
    final s2Kg = _scopeCO2(receipts, 2);
    final s3Kg = _scopeCO2(receipts, 3);
    final gitaRows = _gitaItems(receipts);
    final totalGita = receipts.where((r) => r.gitaEligible).fold(0.0, (s, r) => s + r.gitaAllowance);
    final carbonTax = totalT * 15;

    // Section header (merged across columns)
    addRow(['EMISSIONS SUMMARY', '', '', '', '', '', '', ''], style: sectionHdrStyle(greenHex));

    // Table header
    addRow(['Metric', '', '', 'kg CO₂e', 'Tonnes CO₂e', '% of Total', '', ''], style: tableHdrStyle(greenHex));

    // Data rows
    addRow(['Total Emissions', '', '', totalKg, totalT, '100.0%', '', ''],
      styles: [dataStyle(bg: greenLtHex, bold: true), dataStyle(bg: greenLtHex), dataStyle(bg: greenLtHex),
               dataStyle(bg: greenLtHex, bold: true), dataStyle(bg: greenLtHex, bold: true), dataStyle(bg: greenLtHex, bold: true),
               dataStyle(bg: greenLtHex), dataStyle(bg: greenLtHex)]);
    addRow(['Scope 1 – Direct', '', '', s1Kg, s1Kg / 1000, _pct(s1Kg, totalKg), '', ''], style: dataStyle());
    addRow(['Scope 2 – Energy (Indirect)', '', '', s2Kg, s2Kg / 1000, _pct(s2Kg, totalKg), '', ''], style: dataStyle());
    addRow(['Scope 3 – Other Indirect', '', '', s3Kg, s3Kg / 1000, _pct(s3Kg, totalKg), '', ''], style: dataStyle());
    blankRow();

    // Financial
    addRow(['Total Receipts:', receipts.length, '', 'Total Spend:', totalRM, '', 'Est. Carbon Tax:', carbonTax],
      styles: [medStyle(), dataStyle(bold: true), null, medStyle(), dataStyle(bold: true), null, medStyle(), dataStyle(bold: true)]);
    blankRow();
    blankRow();

    // ════════════════════════════════════════════════════
    // SCOPE DETAILS
    // ════════════════════════════════════════════════════
    void addScopeSection(String title, int scope, xl.ExcelColor hdrColor, xl.ExcelColor altColor) {
      final items = _itemsForScope(receipts, scope);
      if (items.isEmpty) return;

      addRow([title, '', '', '', '', '', '', ''], style: sectionHdrStyle(hdrColor));
      addRow(['Date', 'Vendor', 'Item', 'Category', 'Quantity', 'Price (RM)', 'CO₂ (kg)', 'CO₂ (t)'], style: tableHdrStyle(hdrColor));

      for (int i = 0; i < items.length; i++) {
        final bg = i.isEven ? whiteHex : altColor;
        addRow([items[i].date, items[i].vendor, items[i].item, items[i].category,
                items[i].qty, items[i].price, items[i].co2Kg, items[i].co2T],
          styles: [medStyle(bg: bg), dataStyle(bg: bg), dataStyle(bg: bg, bold: true), dataStyle(bg: bg),
                   medStyle(bg: bg), dataStyle(bg: bg), dataStyle(bg: bg), medStyle(bg: bg)]);
      }

      // Scope total
      final scopeKg = _scopeCO2(receipts, scope);
      addRow(['', '', '', '', '', 'TOTAL:', _n1.format(scopeKg), '${_n2.format(scopeKg/1000)} t'],
        styles: [null, null, null, null, null,
          totalStyle(altColor, hdrColor), totalStyle(altColor, hdrColor), totalStyle(altColor, hdrColor)]);
      blankRow();
      blankRow();
    }

    addScopeSection('SCOPE 1 – DIRECT EMISSIONS', 1, s1Hex, s1LtHex);
    addScopeSection('SCOPE 2 – ENERGY INDIRECT EMISSIONS', 2, s2Hex, s2LtHex);
    addScopeSection('SCOPE 3 – OTHER INDIRECT EMISSIONS', 3, s3Hex, s3LtHex);

    // ════════════════════════════════════════════════════
    // GITA TAX SAVINGS
    // ════════════════════════════════════════════════════
    if (gitaRows.isNotEmpty) {
      addRow(['GITA TAX SAVINGS', '', '', '', '', '', '', ''], style: sectionHdrStyle(greenHex));
      addRow(['Date', 'Vendor', 'Item', 'Tier', 'GITA Category', 'Price (RM)', 'Tax Savings', ''], style: tableHdrStyle(greenHex));

      for (int i = 0; i < gitaRows.length; i++) {
        final bg = i.isEven ? whiteHex : greenLtHex;
        addRow([gitaRows[i].date, gitaRows[i].vendor, gitaRows[i].item, gitaRows[i].tier,
                gitaRows[i].cat, gitaRows[i].price, gitaRows[i].savings, ''],
          styles: [medStyle(bg: bg), dataStyle(bg: bg), dataStyle(bg: bg, bold: true), dataStyle(bg: bg),
                   dataStyle(bg: bg), dataStyle(bg: bg), dataStyle(bg: bg, bold: true), dataStyle(bg: bg)]);
      }

      addRow(['', '', '', '', '', 'TOTAL:', _rm.format(totalGita), ''],
        styles: [null, null, null, null, null,
          totalStyle(greenLtHex, greenHex), totalStyle(greenLtHex, greenHex), null]);
    }

    // Remove default Sheet1
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    return Uint8List.fromList(excel.encode()!);
  }
}

// ── Data classes ──────────────────────────────────────────────────────────

class _ItemRow {
  final String date, vendor, item, category, qty, price, co2Kg, co2T;
  const _ItemRow({
    required this.date, required this.vendor, required this.item,
    required this.category, required this.qty, required this.price,
    required this.co2Kg, required this.co2T,
  });
}

class _GitaRow {
  final String date, vendor, item, tier, cat, price, savings;
  const _GitaRow({
    required this.date, required this.vendor, required this.item,
    required this.tier, required this.cat, required this.price,
    required this.savings,
  });
}
