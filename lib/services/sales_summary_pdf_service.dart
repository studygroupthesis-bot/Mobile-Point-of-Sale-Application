import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SalesSummaryPdfService {
  static final NumberFormat _moneyFmt =
      NumberFormat.currency(locale: 'en_PH', symbol: 'PHP ');
  static final DateFormat _dateFmt = DateFormat('MM/dd/yy');
  static final DateFormat _dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  static double _safeToDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _safeToInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  static DateTime _parseTxDate(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];

    if (createdAt != null && createdAt.runtimeType.toString() == 'Timestamp') {
      try {
        return createdAt.toDate() as DateTime;
      } catch (_) {}
    }

    final local = data['createdAtLocal'];
    if (local is String) {
      final parsed = DateTime.tryParse(local);
      if (parsed != null) return parsed;
    }

    return DateTime.now();
  }

  static String _money(double value) => _moneyFmt.format(value);

  static String _fmtRate(double value) {
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<void> generateAndOpenPdf({
    required String storeName,
    required String filterLabel,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final report = _buildReport(
      storeName: storeName,
      filterLabel: filterLabel,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      transactions: transactions,
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _buildHeader(
            storeName: storeName,
            filterLabel: filterLabel,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          pw.SizedBox(height: 14),
          _buildSimpleTable(
            title: 'Summary Totals',
            headers: const ['Metric', 'Value'],
            rows: [
              ['Total Sales', _money(report.totalSales)],
              ['Subtotal Sales', _money(report.subtotalSales)],
              ['Taxable Sales', _money(report.taxableSales)],
              ['Tax Collected', _money(report.taxCollected)],
              ['Non-Tax Sales', _money(report.nonTaxSales)],
              ['Transactions', '${report.transactionCount}'],
              ['Successful Transactions', '${report.successCount}'],
              ['Items Sold (Qty)', '${report.quantitySold}'],
            ],
          ),
          pw.SizedBox(height: 14),
          _buildSimpleTable(
            title: 'Payment Breakdown',
            headers: const ['Payment Type', 'Amount'],
            rows: [
              ['Cash Sales', _money(report.cashSales)],
              ['GCash Sales', _money(report.gcashSales)],
              ['Other Sales', _money(report.otherSales)],
              ['Cash Received', _money(report.cashReceived)],
              ['Change Given', _money(report.changeGiven)],
              ['Net Cash Kept', _money(report.netCashKept)],
            ],
          ),
          pw.SizedBox(height: 14),
          _buildSimpleTable(
            title: 'Tax Breakdown',
            headers: const [
              'Tax Name',
              'Rate',
              'Type',
              'Taxable Sales',
              'Tax Amount'
            ],
            rows: report.taxRows.isEmpty
                ? [
                    ['No tax data', '-', '-', _money(0), _money(0)],
                  ]
                : report.taxRows
                    .map((e) => [
                          e.taxName,
                          '${_fmtRate(e.taxRate)}%',
                          e.taxInclusive ? 'Inclusive' : 'Exclusive',
                          _money(e.taxableSales),
                          _money(e.taxAmount),
                        ])
                    .toList(),
          ),
          pw.SizedBox(height: 14),
          _buildSimpleTable(
            title: 'Daily Audit Breakdown',
            headers: const [
              'Date',
              'Transactions',
              'Gross Sales',
              'Taxable Sales',
              'Tax',
              'Cash',
              'GCash'
            ],
            rows: report.dailyRows.isEmpty
                ? [
                    [
                      'No data',
                      '0',
                      _money(0),
                      _money(0),
                      _money(0),
                      _money(0),
                      _money(0)
                    ],
                  ]
                : report.dailyRows
                    .map((e) => [
                          _dateFmt.format(e.date),
                          '${e.transactionCount}',
                          _money(e.totalSales),
                          _money(e.taxableSales),
                          _money(e.taxCollected),
                          _money(e.cashSales),
                          _money(e.gcashSales),
                        ])
                    .toList(),
          ),
          pw.SizedBox(height: 14),
          _buildSimpleTable(
            title: 'Audit Notes',
            headers: const ['Field', 'Value'],
            rows: [
              ['Generated At', _dateTimeFmt.format(DateTime.now())],
              ['Store', storeName],
              ['Filter', filterLabel],
              [
                'Range',
                '${_dateFmt.format(rangeStart)} - ${_dateFmt.format(rangeEnd)}'
              ],
              ['Item Lines', '${report.itemLineCount}'],
              ['Non-Success Transactions', '${report.nonSuccessCount}'],
            ],
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'sales_summary_${_dayKey(rangeStart)}_${_dayKey(rangeEnd)}.pdf',
    );
  }

  static Future<void> generateAndSharePdf({
    required String storeName,
    required String filterLabel,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final bytes = await _buildPdfBytes(
      storeName: storeName,
      filterLabel: filterLabel,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      transactions: transactions,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'sales_summary_${_dayKey(rangeStart)}_${_dayKey(rangeEnd)}.pdf',
    );
  }

  static Future<Uint8List> _buildPdfBytes({
    required String storeName,
    required String filterLabel,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final report = _buildReport(
      storeName: storeName,
      filterLabel: filterLabel,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      transactions: transactions,
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _buildHeader(
            storeName: storeName,
            filterLabel: filterLabel,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          pw.SizedBox(height: 14),
          _buildSimpleTable(
            title: 'Summary Totals',
            headers: const ['Metric', 'Value'],
            rows: [
              ['Total Sales', _money(report.totalSales)],
              ['Subtotal Sales', _money(report.subtotalSales)],
              ['Taxable Sales', _money(report.taxableSales)],
              ['Tax Collected', _money(report.taxCollected)],
              ['Non-Tax Sales', _money(report.nonTaxSales)],
              ['Transactions', '${report.transactionCount}'],
              ['Successful Transactions', '${report.successCount}'],
              ['Items Sold (Qty)', '${report.quantitySold}'],
            ],
          ),
          pw.SizedBox(height: 14),
          _buildSimpleTable(
            title: 'Payment Breakdown',
            headers: const ['Payment Type', 'Amount'],
            rows: [
              ['Cash Sales', _money(report.cashSales)],
              ['GCash Sales', _money(report.gcashSales)],
              ['Other Sales', _money(report.otherSales)],
              ['Cash Received', _money(report.cashReceived)],
              ['Change Given', _money(report.changeGiven)],
              ['Net Cash Kept', _money(report.netCashKept)],
            ],
          ),
          pw.SizedBox(height: 14),
          _buildSimpleTable(
            title: 'Tax Breakdown',
            headers: const [
              'Tax Name',
              'Rate',
              'Type',
              'Taxable Sales',
              'Tax Amount'
            ],
            rows: report.taxRows.isEmpty
                ? [
                    ['No tax data', '-', '-', _money(0), _money(0)],
                  ]
                : report.taxRows
                    .map((e) => [
                          e.taxName,
                          '${_fmtRate(e.taxRate)}%',
                          e.taxInclusive ? 'Inclusive' : 'Exclusive',
                          _money(e.taxableSales),
                          _money(e.taxAmount),
                        ])
                    .toList(),
          ),
          pw.SizedBox(height: 14),
          _buildSimpleTable(
            title: 'Daily Audit Breakdown',
            headers: const [
              'Date',
              'Transactions',
              'Gross Sales',
              'Taxable Sales',
              'Tax',
              'Cash',
              'GCash'
            ],
            rows: report.dailyRows.isEmpty
                ? [
                    [
                      'No data',
                      '0',
                      _money(0),
                      _money(0),
                      _money(0),
                      _money(0),
                      _money(0)
                    ],
                  ]
                : report.dailyRows
                    .map((e) => [
                          _dateFmt.format(e.date),
                          '${e.transactionCount}',
                          _money(e.totalSales),
                          _money(e.taxableSales),
                          _money(e.taxCollected),
                          _money(e.cashSales),
                          _money(e.gcashSales),
                        ])
                    .toList(),
          ),
        ],
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  static _SalesSummaryReport _buildReport({
    required String storeName,
    required String filterLabel,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<Map<String, dynamic>> transactions,
  }) {
    double totalSales = 0;
    double subtotalSales = 0;
    double taxableSalesTotal = 0;
    double taxCollected = 0;
    double nonTaxSales = 0;

    double cashSales = 0;
    double gcashSales = 0;
    double otherSales = 0;
    double cashReceived = 0;
    double changeGiven = 0;

    int transactionCount = 0;
    int successCount = 0;
    int nonSuccessCount = 0;
    int itemLineCount = 0;
    int quantitySold = 0;

    final Map<String, _TaxBucket> taxMap = {};
    final Map<String, _DailyBucket> dailyMap = {};

    for (final tx in transactions) {
      final subtotal = _safeToDouble(tx['subtotal']);
      final total = _safeToDouble(
        tx['grandTotal'],
        fallback: _safeToDouble(tx['total']),
      );
      final tax = _safeToDouble(
        tx['tax'],
        fallback: _safeToDouble(tx['taxAmount']),
      );
      final taxEnabled = (tx['taxEnabled'] as bool?) ?? (tax > 0);
      final taxInclusive = (tx['taxInclusive'] as bool?) ?? true;

      final taxableSales = _safeToDouble(
        tx['taxableSales'],
        fallback: taxEnabled
            ? (taxInclusive ? (subtotal - tax) : subtotal)
            : subtotal,
      );

      final taxName = (tx['taxName'] ?? 'VAT').toString();
      final taxRate = _safeToDouble(tx['taxRate'], fallback: 12.0);

      final paymentMode = (tx['paymentMode'] ?? tx['paymentMethod'] ?? 'Cash')
          .toString()
          .toLowerCase();

      final amountReceived = _safeToDouble(tx['amountReceived']);
      final change = _safeToDouble(tx['change']);

      final status = (tx['status'] ?? 'Success').toString();
      final isSuccess = status.toLowerCase() == 'success';

      final txDate = _parseTxDate(tx);
      final dayKey = _dayKey(txDate);

      final rawItems = (tx['items'] as List?) ?? [];
      itemLineCount += rawItems.length;

      for (final item in rawItems) {
        final map = Map<String, dynamic>.from(item as Map);
        quantitySold += _safeToInt(map['qty']);
      }

      transactionCount += 1;
      if (isSuccess) {
        successCount += 1;
      } else {
        nonSuccessCount += 1;
      }

      totalSales += total;
      subtotalSales += subtotal;

      if (taxEnabled) {
        taxableSalesTotal += taxableSales;
        taxCollected += tax;

        final taxKey = '$taxName|${taxRate.toStringAsFixed(4)}|$taxInclusive';
        taxMap.putIfAbsent(
          taxKey,
          () => _TaxBucket(
            taxName: taxName,
            taxRate: taxRate,
            taxInclusive: taxInclusive,
            taxableSales: 0,
            taxAmount: 0,
          ),
        );
        taxMap[taxKey] = taxMap[taxKey]!.copyWith(
          taxableSales: taxMap[taxKey]!.taxableSales + taxableSales,
          taxAmount: taxMap[taxKey]!.taxAmount + tax,
        );
      } else {
        nonTaxSales += total;
      }

      if (paymentMode == 'cash') {
        cashSales += total;
        cashReceived += amountReceived;
        changeGiven += change;
      } else if (paymentMode == 'gcash') {
        gcashSales += total;
      } else {
        otherSales += total;
      }

      dailyMap.putIfAbsent(
        dayKey,
        () => _DailyBucket(
          date: DateTime(txDate.year, txDate.month, txDate.day),
          transactionCount: 0,
          totalSales: 0,
          taxableSales: 0,
          taxCollected: 0,
          cashSales: 0,
          gcashSales: 0,
        ),
      );

      final current = dailyMap[dayKey]!;
      dailyMap[dayKey] = current.copyWith(
        transactionCount: current.transactionCount + 1,
        totalSales: current.totalSales + total,
        taxableSales: current.taxableSales + taxableSales,
        taxCollected: current.taxCollected + tax,
        cashSales: current.cashSales + (paymentMode == 'cash' ? total : 0),
        gcashSales: current.gcashSales + (paymentMode == 'gcash' ? total : 0),
      );
    }

    final taxRows = taxMap.values.toList()
      ..sort((a, b) => a.taxName.compareTo(b.taxName));

    final dailyRows = dailyMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return _SalesSummaryReport(
      totalSales: totalSales,
      subtotalSales: subtotalSales,
      taxableSales: taxableSalesTotal,
      taxCollected: taxCollected,
      nonTaxSales: nonTaxSales,
      cashSales: cashSales,
      gcashSales: gcashSales,
      otherSales: otherSales,
      cashReceived: cashReceived,
      changeGiven: changeGiven,
      netCashKept: cashReceived - changeGiven,
      transactionCount: transactionCount,
      successCount: successCount,
      nonSuccessCount: nonSuccessCount,
      itemLineCount: itemLineCount,
      quantitySold: quantitySold,
      taxRows: taxRows,
      dailyRows: dailyRows,
    );
  }

  static pw.Widget _buildHeader({
    required String storeName,
    required String filterLabel,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Sales Summary Report',
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Store: $storeName'),
              pw.Text('Filter: $filterLabel'),
              pw.Text(
                'Range: ${_dateFmt.format(rangeStart)} - ${_dateFmt.format(rangeEnd)}',
              ),
              pw.Text('Generated: ${_dateTimeFmt.format(DateTime.now())}'),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSimpleTable({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 10,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey700,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {
              for (int i = 0; i < headers.length; i++)
                i: i == 0 ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
            },
            cellPadding: const pw.EdgeInsets.all(6),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesSummaryReport {
  final double totalSales;
  final double subtotalSales;
  final double taxableSales;
  final double taxCollected;
  final double nonTaxSales;

  final double cashSales;
  final double gcashSales;
  final double otherSales;
  final double cashReceived;
  final double changeGiven;
  final double netCashKept;

  final int transactionCount;
  final int successCount;
  final int nonSuccessCount;
  final int itemLineCount;
  final int quantitySold;

  final List<_TaxBucket> taxRows;
  final List<_DailyBucket> dailyRows;

  const _SalesSummaryReport({
    required this.totalSales,
    required this.subtotalSales,
    required this.taxableSales,
    required this.taxCollected,
    required this.nonTaxSales,
    required this.cashSales,
    required this.gcashSales,
    required this.otherSales,
    required this.cashReceived,
    required this.changeGiven,
    required this.netCashKept,
    required this.transactionCount,
    required this.successCount,
    required this.nonSuccessCount,
    required this.itemLineCount,
    required this.quantitySold,
    required this.taxRows,
    required this.dailyRows,
  });
}

class _TaxBucket {
  final String taxName;
  final double taxRate;
  final bool taxInclusive;
  final double taxableSales;
  final double taxAmount;

  const _TaxBucket({
    required this.taxName,
    required this.taxRate,
    required this.taxInclusive,
    required this.taxableSales,
    required this.taxAmount,
  });

  _TaxBucket copyWith({
    String? taxName,
    double? taxRate,
    bool? taxInclusive,
    double? taxableSales,
    double? taxAmount,
  }) {
    return _TaxBucket(
      taxName: taxName ?? this.taxName,
      taxRate: taxRate ?? this.taxRate,
      taxInclusive: taxInclusive ?? this.taxInclusive,
      taxableSales: taxableSales ?? this.taxableSales,
      taxAmount: taxAmount ?? this.taxAmount,
    );
  }
}

class _DailyBucket {
  final DateTime date;
  final int transactionCount;
  final double totalSales;
  final double taxableSales;
  final double taxCollected;
  final double cashSales;
  final double gcashSales;

  const _DailyBucket({
    required this.date,
    required this.transactionCount,
    required this.totalSales,
    required this.taxableSales,
    required this.taxCollected,
    required this.cashSales,
    required this.gcashSales,
  });

  _DailyBucket copyWith({
    DateTime? date,
    int? transactionCount,
    double? totalSales,
    double? taxableSales,
    double? taxCollected,
    double? cashSales,
    double? gcashSales,
  }) {
    return _DailyBucket(
      date: date ?? this.date,
      transactionCount: transactionCount ?? this.transactionCount,
      totalSales: totalSales ?? this.totalSales,
      taxableSales: taxableSales ?? this.taxableSales,
      taxCollected: taxCollected ?? this.taxCollected,
      cashSales: cashSales ?? this.cashSales,
      gcashSales: gcashSales ?? this.gcashSales,
    );
  }
}
