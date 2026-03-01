import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:fyllo_ai/models/expense_model.dart';
import 'package:fyllo_ai/utils/currency_util.dart';
import 'package:intl/intl.dart';

class PdfExportService {
  static Future<void> exportExpensesToPdf({
    required List<Expense> expenses,
    required String userPlan,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();
    
    // Fetch user jurisdiction for correct currency
    final jurisdiction = await CurrencyUtil.getUserJurisdiction();

    // Load NotoSans for all jurisdictions as requested (thick professional look)
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    
    // Create a theme with loaded fonts
    final theme = pw.ThemeData.withFont(
      base: font,
      bold: fontBold,
    );
    
    final currencyFormat = CurrencyUtil.getCurrencyFormat(jurisdiction);
    // Simplified format specifically for PDF: Use "AED" instead of symbol for UAE to avoid reversal issues
    String Function(double) formatCurrency = (val) {
      String formatted = currencyFormat.format(val);
      if (jurisdiction.toUpperCase() == 'UAE') {
        return formatted.replaceAll('د.إ', 'AED');
      }
      return formatted;
    };
    
    final dateFormat = DateFormat.yMMMd();

    // Filter expenses by date range if provided
    List<Expense> filteredExpenses = expenses;
    if (startDate != null || endDate != null) {
      filteredExpenses = expenses.where((expense) {
        if (startDate != null && expense.date.isBefore(startDate)) return false;
        if (endDate != null && expense.date.isAfter(endDate)) return false;
        return true;
      }).toList();
    }

    // Sort by date descending
    filteredExpenses.sort((a, b) => b.date.compareTo(a.date));

    // Calculate totals
    final totalAmount = filteredExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    // Prepare Assets
    final netImage = await networkImage('https://firebasestorage.googleapis.com/v0/b/fyllo-ai.firebasestorage.app/o/unnamed.png?alt=media&token=1b7a811b-0aac-4316-857e-08ba98d7a92b');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (pw.Context context) {
          return [
            // Modern Split Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Image(netImage, width: 60, height: 60),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'FYLLO AI',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.cyan900,
                      ),
                    ),
                    pw.Text(
                      'Smart Expense Intelligence',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'EXPENSE REPORT',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Plan: ${userPlan.toUpperCase()}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan800)),
                    pw.SizedBox(height: 2),
                    pw.Text('Date: ${DateFormat.yMMMd().format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    if (startDate != null || endDate != null) ...[
                      pw.Text(
                        'Period: ${startDate != null ? dateFormat.format(startDate) : 'Start'} - ${endDate != null ? dateFormat.format(endDate) : 'End'}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Summary Cards
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.cyan50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                      border: pw.Border.all(color: PdfColors.cyan100, width: 1),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL EXPENSES', style: pw.TextStyle(fontSize: 8, color: PdfColors.cyan800, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('${filteredExpenses.length}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                      border: pw.Border.all(color: PdfColors.grey200, width: 1),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL AMOUNT', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        _buildCurrencyWidget(
                          formatCurrency(totalAmount), 
                          jurisdiction, 
                          pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 40),

            // Modern Table
            pw.Text('TRANSACTION LOG', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.SizedBox(height: 10),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(3),
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.cyan800, width: 1.5)),
                  ),
                  children: [
                    _buildTableCell(pw.Text('DATE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)), isHeader: true),
                    _buildTableCell(pw.Text('MERCHANT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)), isHeader: true),
                    _buildTableCell(pw.Text('CATEGORY', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)), isHeader: true),
                    _buildTableCell(pw.Text('AMOUNT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)), isHeader: true),
                    _buildTableCell(pw.Text('TAX IMPACT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)), isHeader: true),
                  ],
                ),
                // Data Rows
                ...filteredExpenses.map((expense) => pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey100, width: 0.5)),
                  ),
                  children: [
                    _buildTableCell(pw.Text(dateFormat.format(expense.date), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800))),
                    _buildTableCell(pw.Text(expense.merchantName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900))),
                    _buildTableCell(pw.Text(expense.category, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800))),
                    _buildTableCell(_buildCurrencyWidget(
                      formatCurrency(expense.amount), 
                      jurisdiction, 
                      pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)
                    )),
                    _buildTableCell(pw.Text(expense.taxImpact, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800))),
                  ],
                )),
              ],
            ),

            // AI Intelligence Section
            if (userPlan == 'pro' || userPlan == 'elite') ...[
              pw.SizedBox(height: 50),
              pw.Text('AI FINANCIAL INTELLIGENCE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
              pw.SizedBox(height: 15),
              ...filteredExpenses.map((expense) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                decoration: pw.BoxDecoration(
                  border: pw.Border(left: pw.BorderSide(color: PdfColors.cyan600, width: 3)),
                  color: PdfColors.grey50,
                ),
                padding: const pw.EdgeInsets.all(16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(expense.merchantName.toUpperCase(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        _buildCurrencyWidget(
                          formatCurrency(expense.amount), 
                          jurisdiction, 
                          pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan800)
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const pw.BoxDecoration(color: PdfColors.cyan100),
                          child: pw.Text(expense.category, style: const pw.TextStyle(fontSize: 8)),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text('Rule: ${expense.deductionType}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'ANALYSIS',
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500, letterSpacing: 1),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      expense.aiAnalysis,
                      style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.5, color: PdfColors.grey800),
                    ),
                  ],
                ),
              )),
            ],

            // Disclaimer Footer
            pw.SizedBox(height: 40),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              child: pw.Text(
                'LEGAL DISCLAIMER: This report is generated by Fyllo AI Intelligence. It is intended for organizational and informational purposes only and does not constitute official tax or legal advice. Please consult with a certified tax professional for official filings.',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ];
        },
      ),
    );

    // Share/Print PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Fyllo_AI_Expenses_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _buildCurrencyWidget(String formatted, String jurisdiction, pw.TextStyle style) {
    // We use a simple Text widget with LTR direction. 
    // Since UAE now uses "AED" (Latin) in the PDF, it won't reverse.
    return pw.Text(formatted, style: style, textDirection: pw.TextDirection.ltr);
  }

  static pw.Widget _buildTableCell(
    pw.Widget content, {
    bool isHeader = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: content,
    );
  }
}
