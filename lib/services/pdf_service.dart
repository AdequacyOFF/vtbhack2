import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bank_account.dart';
import '../models/transaction.dart';
import '../config/api_config.dart';

class PdfService {
  // Limits to prevent "too many pages" error
  static const int maxTransactionsPerAccount = 15;
  static const int maxAccountsInPdf = 10;

  static Future<File> generateAccountStatement({
    required List<BankAccount> accounts,
    required Map<String, List<BankTransaction>> transactionsByAccount,
    required Map<String, double> balances,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final now = DateTime.now();

    // Limit number of accounts to prevent too many pages
    final limitedAccounts = accounts.take(maxAccountsInPdf).toList();

    // Load font that supports Cyrillic
    final fontData = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final baseStyle = pw.TextStyle(font: fontData);
    final boldStyle = pw.TextStyle(font: fontBold, fontWeight: pw.FontWeight.bold);

    // Calculate totals
    double totalBalance = 0;
    for (var account in limitedAccounts) {
      final balanceKey = '${account.bankCode}:${account.accountId}';
      totalBalance += balances[balanceKey] ?? 0;
    }

    final totalAccounts = accounts.length;
    final showingAccounts = limitedAccounts.length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Выписка по счетам',
                  style: boldStyle.copyWith(fontSize: 24),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Дата формирования: ${dateFormat.format(now)}',
                  style: baseStyle.copyWith(fontSize: 12),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Общий баланс: ${totalBalance.toStringAsFixed(2)} RUB',
                  style: boldStyle.copyWith(fontSize: 16),
                ),
                if (showingAccounts < totalAccounts) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Показано $showingAccounts из $totalAccounts счетов',
                    style: baseStyle.copyWith(fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Account sections
          ...limitedAccounts.map((account) {
            final balanceKey = '${account.bankCode}:${account.accountId}';
            final accountBalance = balances[balanceKey] ?? 0;
            final transactions = transactionsByAccount[account.accountId] ?? [];

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Account header
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey300,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        account.displayName,
                        style: boldStyle.copyWith(fontSize: 12),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Банк: ${ApiConfig.getBankName(account.bankCode)}',
                        style: baseStyle.copyWith(fontSize: 9),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'Счет: ${account.identification ?? account.accountId}',
                        style: baseStyle.copyWith(fontSize: 8),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'Баланс: ${accountBalance.toStringAsFixed(2)} ${account.currency}',
                        style: boldStyle.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),

                // Transactions table
                if (transactions.isNotEmpty) ...[
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    children: [
                      // Header row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey200,
                        ),
                        children: [
                          _buildTableCell('Дата', boldStyle, isHeader: true),
                          _buildTableCell('Описание', boldStyle, isHeader: true),
                          _buildTableCell('Категория', boldStyle, isHeader: true),
                          _buildTableCell('Сумма', boldStyle, isHeader: true),
                        ],
                      ),
                      // Data rows
                      ...transactions.take(maxTransactionsPerAccount).map((tx) {
                        final date = DateTime.tryParse(tx.bookingDateTime);
                        final dateStr = date != null
                            ? DateFormat('dd.MM.yy').format(date)
                            : '';
                        final isCredit = tx.isCredit;
                        final amountStr = '${isCredit ? '+' : '-'}${tx.amount} ₽';

                        // Remove emojis from transaction info for PDF
                        final cleanInfo = (tx.transactionInformation ?? '')
                            .replaceAll(RegExp(r'[^\x00-\x7F\u0400-\u04FF]'), '');

                        return pw.TableRow(
                          children: [
                            _buildTableCell(dateStr, baseStyle),
                            _buildTableCell(cleanInfo, baseStyle),
                            _buildTableCell(tx.category, baseStyle),
                            _buildTableCell(
                              '${isCredit ? '+' : '-'}${tx.amount} RUB',
                              baseStyle,
                              color: isCredit ? PdfColors.green : PdfColors.red,
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                  if (transactions.length > maxTransactionsPerAccount)
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Показано $maxTransactionsPerAccount из ${transactions.length} транзакций',
                        style: baseStyle.copyWith(fontSize: 10, color: PdfColors.grey600),
                      ),
                    ),
                ],

                if (transactions.isEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Нет транзакций',
                      style: baseStyle.copyWith(fontSize: 10),
                    ),
                  ),

                pw.SizedBox(height: 12),
              ],
            );
          }).toList(),
        ],
      ),
    );

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/account_statement_${now.millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildTableCell(
    String text,
    pw.TextStyle baseStyle, {
    bool isHeader = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        style: baseStyle.copyWith(
          fontSize: isHeader ? 9 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  static Future<void> sharePdf(File file) async {
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: file.path.split('/').last,
    );
  }

  static Future<void> printPdf(File file) async {
    await Printing.layoutPdf(
      onLayout: (format) async => await file.readAsBytes(),
    );
  }
}
