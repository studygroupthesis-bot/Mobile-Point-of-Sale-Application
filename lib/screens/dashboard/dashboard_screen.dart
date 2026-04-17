import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../transaction/transaction_screen.dart';
import '../Notifications/notifications_screen.dart';

enum DashboardFilter {
  thisWeek,
  lastWeek,
  monthly,
  yearly,
}

enum DashboardExportAction {
  pdf,
  csv,
}

class DashboardStoreContext {
  final String storeId;
  final String storeName;
  final String? logoUrl;

  const DashboardStoreContext({
    required this.storeId,
    required this.storeName,
    this.logoUrl,
  });
}

class DashboardRange {
  final DateTime start;
  final DateTime end;
  final String title;
  final String subtitle;

  const DashboardRange({
    required this.start,
    required this.end,
    required this.title,
    required this.subtitle,
  });
}

class DashboardBarData {
  final String label;
  final double value;

  const DashboardBarData({
    required this.label,
    required this.value,
  });
}

class DashboardTaxRow {
  final String taxName;
  final double taxRate;
  final bool taxInclusive;
  final double taxableSales;
  final double taxAmount;

  const DashboardTaxRow({
    required this.taxName,
    required this.taxRate,
    required this.taxInclusive,
    required this.taxableSales,
    required this.taxAmount,
  });
}

class DashboardDailyAuditRow {
  final DateTime date;
  final int transactionCount;
  final double grossSales;
  final double taxableSales;
  final double taxCollected;
  final double cashSales;
  final double gcashSales;

  const DashboardDailyAuditRow({
    required this.date,
    required this.transactionCount,
    required this.grossSales,
    required this.taxableSales,
    required this.taxCollected,
    required this.cashSales,
    required this.gcashSales,
  });
}

class DashboardReportData {
  final String storeName;
  final String filterLabel;
  final String rangeLabel;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final DateTime generatedAt;

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
  final int totalProductsSold;
  final int itemLineCount;

  final List<DashboardTaxRow> taxRows;
  final List<DashboardDailyAuditRow> dailyAuditRows;

  const DashboardReportData({
    required this.storeName,
    required this.filterLabel,
    required this.rangeLabel,
    required this.rangeStart,
    required this.rangeEnd,
    required this.generatedAt,
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
    required this.totalProductsSold,
    required this.itemLineCount,
    required this.taxRows,
    required this.dailyAuditRows,
  });
}

class DashboardLowStockItem {
  final String id;
  final String name;
  final String category;
  final int stockQty;
  final String barcode;

  const DashboardLowStockItem({
    required this.id,
    required this.name,
    required this.category,
    required this.stockQty,
    required this.barcode,
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
  final double grossSales;
  final double taxableSales;
  final double taxCollected;
  final double cashSales;
  final double gcashSales;

  const _DailyBucket({
    required this.date,
    required this.transactionCount,
    required this.grossSales,
    required this.taxableSales,
    required this.taxCollected,
    required this.cashSales,
    required this.gcashSales,
  });

  _DailyBucket copyWith({
    DateTime? date,
    int? transactionCount,
    double? grossSales,
    double? taxableSales,
    double? taxCollected,
    double? cashSales,
    double? gcashSales,
  }) {
    return _DailyBucket(
      date: date ?? this.date,
      transactionCount: transactionCount ?? this.transactionCount,
      grossSales: grossSales ?? this.grossSales,
      taxableSales: taxableSales ?? this.taxableSales,
      taxCollected: taxCollected ?? this.taxCollected,
      cashSales: cashSales ?? this.cashSales,
      gcashSales: gcashSales ?? this.gcashSales,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const DashboardScreen({
    super.key,
    this.onNavigateToTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const bool allowYearly = false;
  static const int lowStockThreshold = 5;

  late final Future<DashboardStoreContext> _storeFuture;
  DashboardFilter _selectedFilter = DashboardFilter.thisWeek;

  @override
  void initState() {
    super.initState();
    _storeFuture = _loadStoreContext();
  }

  Future<DashboardStoreContext> _loadStoreContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in.');

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final storeId = userSnap.data()?['storeId'] as String?;
    if (storeId == null || storeId.isEmpty) {
      throw Exception('Missing storeId in users/${user.uid}.');
    }

    final storeSnap = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .get();

    final storeData = storeSnap.data() ?? {};
    final storeName =
        (storeData['business_name'] ?? storeData['name'] ?? 'My Store')
            .toString();

    final logoUrl = (storeData['logo_url'] ?? '').toString().trim();

    return DashboardStoreContext(
      storeId: storeId,
      storeName: storeName,
      logoUrl: logoUrl.isEmpty ? null : logoUrl,
    );
  }

  DashboardRange _currentRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final startThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final endThisWeek = startThisWeek.add(const Duration(days: 7));

    switch (_selectedFilter) {
      case DashboardFilter.thisWeek:
        return DashboardRange(
          start: startThisWeek,
          end: endThisWeek,
          title: "This Week's Sales",
          subtitle: _rangeText(
            startThisWeek,
            endThisWeek.subtract(const Duration(days: 1)),
          ),
        );

      case DashboardFilter.lastWeek:
        final startLastWeek = startThisWeek.subtract(const Duration(days: 7));
        final endLastWeek = startThisWeek;
        return DashboardRange(
          start: startLastWeek,
          end: endLastWeek,
          title: "Last Week's Sales",
          subtitle: _rangeText(
            startLastWeek,
            endLastWeek.subtract(const Duration(days: 1)),
          ),
        );

      case DashboardFilter.monthly:
        final startMonth = DateTime(now.year, now.month, 1);
        final endMonth = DateTime(now.year, now.month + 1, 1);
        return DashboardRange(
          start: startMonth,
          end: endMonth,
          title: "This Month's Sales",
          subtitle: _monthText(startMonth),
        );

      case DashboardFilter.yearly:
        final startYear = DateTime(now.year, 1, 1);
        final endYear = DateTime(now.year + 1, 1, 1);
        return DashboardRange(
          start: startYear,
          end: endYear,
          title: "This Year's Sales",
          subtitle: now.year.toString(),
        );
    }
  }

  String _monthText(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _rangeText(DateTime start, DateTime end) {
    return '${_shortDate(start)} - ${_shortDate(end)}';
  }

  String _shortDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final yy = d.year.toString().substring(2);
    return '$mm/$dd/$yy';
  }

  String _money(num value) => '₱ ${value.toStringAsFixed(2)}';

  String _compactMoneyLabel(double value) {
    if (value >= 1000000) {
      return '₱${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '₱${(value / 1000).toStringAsFixed(1)}k';
    }
    return '₱${value.toStringAsFixed(0)}';
  }

  double _safeToDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _safeToInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  DateTime _txDate(Map<String, dynamic> data) {
    final ts = data['createdAt'];
    if (ts is Timestamp) return ts.toDate();

    final local = data['createdAtLocal'];
    if (local is String) {
      final parsed = DateTime.tryParse(local);
      if (parsed != null) return parsed;
    }

    return DateTime.now();
  }

  String _dateKey(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _selectedFilterLabel() {
    switch (_selectedFilter) {
      case DashboardFilter.thisWeek:
        return 'This Week';
      case DashboardFilter.lastWeek:
        return 'Last Week';
      case DashboardFilter.monthly:
        return 'Monthly';
      case DashboardFilter.yearly:
        return 'Yearly';
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _goToTab(int index) {
    final callback = widget.onNavigateToTab;
    if (callback != null) {
      callback(index);
    }
  }

  void _openTransactionScreen(DashboardStoreContext store) {
    if (widget.onNavigateToTab != null) {
      _goToTab(2);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionScreen(
          storeId: store.storeId,
          storeName: store.storeName,
          isActive: true,
        ),
      ),
    );
  }

  int _sumProducts(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int total = 0;

    for (final doc in docs) {
      final data = doc.data();
      final rawItems = data['items'];

      if (rawItems is List) {
        for (final item in rawItems) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            total += (map['qty'] as num?)?.toInt() ?? 0;
          }
        }
      }
    }

    return total;
  }

  int _countItemLines(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int total = 0;

    for (final doc in docs) {
      final rawItems = doc.data()['items'];
      if (rawItems is List) {
        total += rawItems.length;
      }
    }

    return total;
  }

  List<DropdownMenuItem<DashboardFilter>> _filterItems() {
    final items = <DropdownMenuItem<DashboardFilter>>[
      const DropdownMenuItem(
        value: DashboardFilter.thisWeek,
        child: Text('This week'),
      ),
      const DropdownMenuItem(
        value: DashboardFilter.lastWeek,
        child: Text('Last week'),
      ),
      const DropdownMenuItem(
        value: DashboardFilter.monthly,
        child: Text('Monthly'),
      ),
    ];

    if (allowYearly) {
      items.add(
        const DropdownMenuItem(
          value: DashboardFilter.yearly,
          child: Text('Yearly'),
        ),
      );
    }

    return items;
  }

  int _currentStockFromItem(Map<String, dynamic> data) {
    if (data['stockQty'] != null) return _safeToInt(data['stockQty']);
    if (data['stock'] != null) return _safeToInt(data['stock']);
    if (data['quantity'] != null) return _safeToInt(data['quantity']);
    return 0;
  }

  List<DashboardLowStockItem> _buildLowStockItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final items = <DashboardLowStockItem>[];

    for (final doc in docs) {
      final data = doc.data();
      final trackStock = (data['trackStock'] as bool?) ?? true;
      if (!trackStock) continue;

      final stockQty = _currentStockFromItem(data);
      if (stockQty > lowStockThreshold) continue;

      items.add(
        DashboardLowStockItem(
          id: doc.id,
          name: (data['name'] ?? 'Unnamed Item').toString(),
          category: (data['category'] ?? 'Uncategorized').toString(),
          stockQty: stockQty,
          barcode: (data['barcode'] ?? '').toString(),
        ),
      );
    }

    items.sort((a, b) {
      final stockCompare = a.stockQty.compareTo(b.stockQty);
      if (stockCompare != 0) return stockCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return items;
  }

  DashboardReportData _buildReportData({
    required DashboardStoreContext store,
    required DashboardRange range,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
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
    final totalProductsSold = _sumProducts(docs);
    final itemLineCount = _countItemLines(docs);

    final Map<String, _TaxBucket> taxMap = {};
    final Map<String, _DailyBucket> dailyMap = {};

    for (final doc in docs) {
      final data = doc.data();

      final subtotal = _safeToDouble(data['subtotal']);
      final total = _safeToDouble(
        data['grandTotal'],
        fallback: _safeToDouble(data['total']),
      );
      final tax = _safeToDouble(
        data['tax'],
        fallback: _safeToDouble(data['taxAmount']),
      );

      final taxEnabled = (data['taxEnabled'] as bool?) ?? (tax > 0);
      final taxInclusive = (data['taxInclusive'] as bool?) ?? true;
      final taxName = (data['taxName'] ?? 'VAT').toString();
      final taxRate = _safeToDouble(data['taxRate'], fallback: 12.0);

      final taxableSales = _safeToDouble(
        data['taxableSales'],
        fallback: taxEnabled
            ? (taxInclusive ? (subtotal - tax) : subtotal)
            : subtotal,
      );

      final paymentMode =
          (data['paymentMode'] ?? data['paymentMethod'] ?? 'Cash')
              .toString()
              .toLowerCase();

      final amountReceived = _safeToDouble(data['amountReceived']);
      final change = _safeToDouble(data['change']);

      final status = (data['status'] ?? 'Success').toString();
      final isSuccess = status.toLowerCase() == 'success';

      final txDate = _txDate(data);
      final dayKey = _dateKey(DateTime(txDate.year, txDate.month, txDate.day));

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

        final bucket = taxMap[taxKey]!;
        taxMap[taxKey] = bucket.copyWith(
          taxableSales: bucket.taxableSales + taxableSales,
          taxAmount: bucket.taxAmount + tax,
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
          grossSales: 0,
          taxableSales: 0,
          taxCollected: 0,
          cashSales: 0,
          gcashSales: 0,
        ),
      );

      final daily = dailyMap[dayKey]!;
      dailyMap[dayKey] = daily.copyWith(
        transactionCount: daily.transactionCount + 1,
        grossSales: daily.grossSales + total,
        taxableSales: daily.taxableSales + taxableSales,
        taxCollected: daily.taxCollected + tax,
        cashSales: daily.cashSales + (paymentMode == 'cash' ? total : 0),
        gcashSales: daily.gcashSales + (paymentMode == 'gcash' ? total : 0),
      );
    }

    final taxRows = taxMap.values
        .map(
          (e) => DashboardTaxRow(
            taxName: e.taxName,
            taxRate: e.taxRate,
            taxInclusive: e.taxInclusive,
            taxableSales: e.taxableSales,
            taxAmount: e.taxAmount,
          ),
        )
        .toList()
      ..sort((a, b) => a.taxName.compareTo(b.taxName));

    final dailyRows = dailyMap.values
        .map(
          (e) => DashboardDailyAuditRow(
            date: e.date,
            transactionCount: e.transactionCount,
            grossSales: e.grossSales,
            taxableSales: e.taxableSales,
            taxCollected: e.taxCollected,
            cashSales: e.cashSales,
            gcashSales: e.gcashSales,
          ),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return DashboardReportData(
      storeName: store.storeName,
      filterLabel: _selectedFilterLabel(),
      rangeLabel: range.subtitle,
      rangeStart: range.start,
      rangeEnd: range.end,
      generatedAt: DateTime.now(),
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
      totalProductsSold: totalProductsSold,
      itemLineCount: itemLineCount,
      taxRows: taxRows,
      dailyAuditRows: dailyRows,
    );
  }

  String _fmtRate(double value) {
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  Future<void> _handleExport(
    DashboardExportAction action,
    DashboardReportData report,
  ) async {
    switch (action) {
      case DashboardExportAction.pdf:
        await _exportSummaryPdf(report);
        break;
      case DashboardExportAction.csv:
        await _copySummaryCsv(report);
        break;
    }
  }

  Future<void> _exportSummaryPdf(DashboardReportData report) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
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
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Store: ${report.storeName}'),
                pw.Text('Filter: ${report.filterLabel}'),
                pw.Text(
                  'Range: ${_shortDate(report.rangeStart)} - ${_shortDate(report.rangeEnd.subtract(const Duration(days: 1)))}',
                ),
                pw.Text('Generated: ${report.generatedAt.toString()}'),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfTable(
            title: 'Summary Totals',
            headers: const ['Metric', 'Value'],
            rows: [
              ['Total Sales', report.totalSales.toStringAsFixed(2)],
              ['Subtotal Sales', report.subtotalSales.toStringAsFixed(2)],
              ['Taxable Sales', report.taxableSales.toStringAsFixed(2)],
              ['Tax Collected', report.taxCollected.toStringAsFixed(2)],
              ['Non-Tax Sales', report.nonTaxSales.toStringAsFixed(2)],
              ['Transactions', '${report.transactionCount}'],
              ['Successful Transactions', '${report.successCount}'],
              ['Non-Success Transactions', '${report.nonSuccessCount}'],
              ['Total Products Sold', '${report.totalProductsSold}'],
              ['Item Lines', '${report.itemLineCount}'],
            ],
          ),
          pw.SizedBox(height: 12),
          _pdfTable(
            title: 'Payment Breakdown',
            headers: const ['Payment Type', 'Amount'],
            rows: [
              ['Cash Sales', report.cashSales.toStringAsFixed(2)],
              ['GCash Sales', report.gcashSales.toStringAsFixed(2)],
              ['Other Sales', report.otherSales.toStringAsFixed(2)],
              ['Cash Received', report.cashReceived.toStringAsFixed(2)],
              ['Change Given', report.changeGiven.toStringAsFixed(2)],
              ['Net Cash Kept', report.netCashKept.toStringAsFixed(2)],
            ],
          ),
          pw.SizedBox(height: 12),
          _pdfTable(
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
                    ['No tax data', '-', '-', '0.00', '0.00'],
                  ]
                : report.taxRows
                    .map((e) => [
                          e.taxName,
                          '${_fmtRate(e.taxRate)}%',
                          e.taxInclusive ? 'Inclusive' : 'Exclusive',
                          e.taxableSales.toStringAsFixed(2),
                          e.taxAmount.toStringAsFixed(2),
                        ])
                    .toList(),
          ),
          pw.SizedBox(height: 12),
          _pdfTable(
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
            rows: report.dailyAuditRows.isEmpty
                ? [
                    ['No data', '0', '0.00', '0.00', '0.00', '0.00', '0.00'],
                  ]
                : report.dailyAuditRows
                    .map((e) => [
                          _shortDate(e.date),
                          '${e.transactionCount}',
                          e.grossSales.toStringAsFixed(2),
                          e.taxableSales.toStringAsFixed(2),
                          e.taxCollected.toStringAsFixed(2),
                          e.cashSales.toStringAsFixed(2),
                          e.gcashSales.toStringAsFixed(2),
                        ])
                    .toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name:
          'sales_summary_${_dateKey(report.rangeStart)}_${_dateKey(report.rangeEnd.subtract(const Duration(days: 1)))}.pdf',
    );
  }

  pw.Widget _pdfTable({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
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
            cellPadding: const pw.EdgeInsets.all(6),
            cellAlignments: {
              for (int i = 0; i < headers.length; i++)
                i: i == 0 ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
            },
          ),
        ],
      ),
    );
  }

  Future<void> _copySummaryCsv(DashboardReportData report) async {
    final lines = <String>[
      'SUMMARY TOTALS',
      'Metric,Value',
      'Store,"${report.storeName}"',
      'Filter,"${report.filterLabel}"',
      'Range,"${_shortDate(report.rangeStart)} - ${_shortDate(report.rangeEnd.subtract(const Duration(days: 1)))}"',
      'Generated At,"${report.generatedAt.toIso8601String()}"',
      'Total Sales,"${report.totalSales.toStringAsFixed(2)}"',
      'Subtotal Sales,"${report.subtotalSales.toStringAsFixed(2)}"',
      'Taxable Sales,"${report.taxableSales.toStringAsFixed(2)}"',
      'Tax Collected,"${report.taxCollected.toStringAsFixed(2)}"',
      'Non-Tax Sales,"${report.nonTaxSales.toStringAsFixed(2)}"',
      'Transactions,"${report.transactionCount}"',
      'Successful Transactions,"${report.successCount}"',
      'Non-Success Transactions,"${report.nonSuccessCount}"',
      'Total Products Sold,"${report.totalProductsSold}"',
      'Item Lines,"${report.itemLineCount}"',
      '',
      'PAYMENT BREAKDOWN',
      'Payment Type,Amount',
      'Cash Sales,"${report.cashSales.toStringAsFixed(2)}"',
      'GCash Sales,"${report.gcashSales.toStringAsFixed(2)}"',
      'Other Sales,"${report.otherSales.toStringAsFixed(2)}"',
      'Cash Received,"${report.cashReceived.toStringAsFixed(2)}"',
      'Change Given,"${report.changeGiven.toStringAsFixed(2)}"',
      'Net Cash Kept,"${report.netCashKept.toStringAsFixed(2)}"',
      '',
      'TAX BREAKDOWN',
      'Tax Name,Rate,Type,Taxable Sales,Tax Amount',
      if (report.taxRows.isEmpty) 'No tax data,-,-,0.00,0.00',
      ...report.taxRows.map(
        (e) =>
            '"${e.taxName}","${_fmtRate(e.taxRate)}%","${e.taxInclusive ? 'Inclusive' : 'Exclusive'}","${e.taxableSales.toStringAsFixed(2)}","${e.taxAmount.toStringAsFixed(2)}"',
      ),
      '',
      'DAILY AUDIT BREAKDOWN',
      'Date,Transactions,Gross Sales,Taxable Sales,Tax,Cash,GCash',
      if (report.dailyAuditRows.isEmpty) 'No data,0,0.00,0.00,0.00,0.00,0.00',
      ...report.dailyAuditRows.map(
        (e) =>
            '"${_shortDate(e.date)}","${e.transactionCount}","${e.grossSales.toStringAsFixed(2)}","${e.taxableSales.toStringAsFixed(2)}","${e.taxCollected.toStringAsFixed(2)}","${e.cashSales.toStringAsFixed(2)}","${e.gcashSales.toStringAsFixed(2)}"',
      ),
    ];

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));

    if (!mounted) return;
    _showSnack('Detailed CSV summary copied to clipboard.');
  }

  List<DashboardBarData> _buildGraphData(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    DashboardRange range,
  ) {
    switch (_selectedFilter) {
      case DashboardFilter.thisWeek:
      case DashboardFilter.lastWeek:
        final labels = ['M', 'T', 'W', 'TH', 'F', 'S', 'SU'];
        final values = List<double>.filled(7, 0);

        for (final doc in docs) {
          final data = doc.data();
          final date = _txDate(data);
          final amount = _safeToDouble(
            data['grandTotal'],
            fallback: _safeToDouble(data['total']),
          );

          final index = date.difference(range.start).inDays;
          if (index >= 0 && index < 7) {
            values[index] += amount;
          }
        }

        return List.generate(
          7,
          (i) => DashboardBarData(label: labels[i], value: values[i]),
        );

      case DashboardFilter.monthly:
        final labels = ['W1', 'W2', 'W3', 'W4', 'W5'];
        final values = List<double>.filled(5, 0);

        for (final doc in docs) {
          final data = doc.data();
          final date = _txDate(data);
          final amount = _safeToDouble(
            data['grandTotal'],
            fallback: _safeToDouble(data['total']),
          );

          int weekIndex = ((date.day - 1) ~/ 7);
          if (weekIndex > 4) weekIndex = 4;

          values[weekIndex] += amount;
        }

        return List.generate(
          5,
          (i) => DashboardBarData(label: labels[i], value: values[i]),
        );

      case DashboardFilter.yearly:
        final labels = [
          'J',
          'F',
          'M',
          'A',
          'M',
          'J',
          'J',
          'A',
          'S',
          'O',
          'N',
          'D'
        ];
        final values = List<double>.filled(12, 0);

        for (final doc in docs) {
          final data = doc.data();
          final date = _txDate(data);
          final amount = _safeToDouble(
            data['grandTotal'],
            fallback: _safeToDouble(data['total']),
          );

          final index = date.month - 1;
          if (index >= 0 && index < 12) {
            values[index] += amount;
          }
        }

        return List.generate(
          12,
          (i) => DashboardBarData(label: labels[i], value: values[i]),
        );
    }
  }

  Color _stockColor(int qty) {
    if (qty <= 0) return Colors.redAccent;
    if (qty <= 2) return Colors.orange;
    if (qty <= lowStockThreshold) return const Color(0xFFB36A00);
    return const Color(0xFF0E6C73);
  }

  String _stockLabel(int qty) {
    if (qty <= 0) return 'Out';
    if (qty <= 2) return '$qty left';
    if (qty <= lowStockThreshold) return '$qty left';
    return 'In stock';
  }

  void _showLowStockSheet(List<DashboardLowStockItem> lowStockItems) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: const BoxDecoration(
            color: Color(0xFFF6FBFA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Low Stock Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0E6C73),
                          ),
                        ),
                      ),
                      Text(
                        '${lowStockItems.length} item${lowStockItems.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Items with stock less than or equal to $lowStockThreshold.',
                      style: const TextStyle(
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: lowStockItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No low-stock items right now.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                          itemCount: lowStockItems.length,
                          itemBuilder: (context, index) {
                            return _buildLowStockTile(
                              lowStockItems[index],
                              showBarcode: true,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openNotificationsScreen(
    DashboardStoreContext store,
    List<DashboardLowStockItem> lowStockItems,
  ) {
    final alerts = lowStockItems.map((item) {
      final isOut = item.stockQty <= 0;
      final isCritical = item.stockQty > 0 && item.stockQty <= 2;

      return {
        'title': isOut ? 'Out of stock' : 'Low stock alert',
        'message': '${item.name} • ${item.category}',
        'trailing': isOut ? 'Out' : '${item.stockQty} left',
        'severity': isOut ? 'out' : (isCritical ? 'critical' : 'warning'),
      };
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          storeName: store.storeName,
          alerts: alerts,
        ),
      ),
    );
  }

  void _showNotificationSheet(List<DashboardLowStockItem> lowStockItems) {
    final notifications = <Map<String, dynamic>>[];

    for (final item in lowStockItems) {
      final color = _stockColor(item.stockQty);

      notifications.add({
        'title': item.stockQty <= 0 ? 'Out of stock' : 'Low stock alert',
        'message': '${item.name} • ${item.category}',
        'trailing': item.stockQty <= 0 ? 'Out' : '${item.stockQty} left',
        'color': color,
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: Color(0xFF0E6C73),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0E6C73),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (notifications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'No notifications right now.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  else
                    ...notifications.map((note) {
                      final Color color = note['color'] as Color;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: color.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              color == Colors.redAccent
                                  ? Icons.error_outline_rounded
                                  : Icons.warning_amber_rounded,
                              color: color,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    note['title'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    note['message'] as String,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              note['trailing'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryGraph(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    DashboardRange range,
  ) {
    final bars = _buildGraphData(docs, range);
    final maxValue = bars.fold<double>(
      0,
      (max, bar) => bar.value > max ? bar.value : max,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            range.subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            child: bars.every((e) => e.value <= 0)
                ? const Center(
                    child: Text(
                      'No sales data for this period.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: bars.map((bar) {
                      final ratio =
                          maxValue <= 0 ? 0.0 : (bar.value / maxValue);
                      final barHeight = 18 + (ratio * 95);

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                bar.value <= 0
                                    ? '0'
                                    : _compactMoneyLabel(bar.value),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 6),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: bar.label == bars.last.label
                                      ? const Color(0xFF0E6C73)
                                      : const Color(0xFF88C7BF),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                bar.label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRecentTransactions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final displayDocs = docs.length > 5 ? docs.take(5).toList() : docs;

    return displayDocs.map((doc) {
      final data = doc.data();
      final invoiceId =
          (data['invoiceNo'] ?? data['invoiceId'] ?? doc.id).toString();
      final amount = _safeToDouble(
        data['grandTotal'],
        fallback: _safeToDouble(data['total']),
      );
      final paymentMode =
          (data['paymentMode'] ?? data['paymentMethod'] ?? 'Cash').toString();

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.receipt_long,
              color: Color(0xFF0E6C73),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice #$invoiceId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    paymentMode,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _money(amount),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildStoreLogo(String? logoUrl) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: (logoUrl != null && logoUrl.isNotEmpty)
          ? Image.network(
              logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Icon(
                  Icons.storefront,
                  color: Color(0xFFB12A87),
                );
              },
            )
          : const Icon(
              Icons.storefront,
              color: Color(0xFFB12A87),
            ),
    );
  }

  Widget _buildDashboardHeader(
    DashboardStoreContext store,
    List<DashboardLowStockItem> lowStockItems,
    DashboardReportData report,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFDDF3F0),
      ),
      child: Row(
        children: [
          _buildStoreLogo(store.logoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              store.storeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F1F1F),
              ),
            ),
          ),
          _buildNotificationBell(store, lowStockItems),
          const SizedBox(width: 8),
          PopupMenuButton<DashboardExportAction>(
            tooltip: 'Export summary',
            surfaceTintColor: Colors.white,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            icon: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.more_vert,
                color: Colors.black87,
              ),
            ),
            onSelected: (value) async {
              await _handleExport(value, report);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: DashboardExportAction.pdf,
                child: Text('Create PDF Summary'),
              ),
              PopupMenuItem(
                value: DashboardExportAction.csv,
                child: Text('Copy CSV Summary'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerActionButton({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1.5,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildNotificationBell(
    DashboardStoreContext store,
    List<DashboardLowStockItem> lowStockItems,
  ) {
    final unreadCount = lowStockItems.length;

    return _headerActionButton(
      onTap: () => _openNotificationsScreen(store, lowStockItems),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: Colors.black87,
          ),
          if (unreadCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
                constraints: const BoxConstraints(minWidth: 18),
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrimarySalesCard(
    DashboardReportData report,
    DashboardRange range,
    DashboardStoreContext store,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  range.title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _money(report.totalSales),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  range.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _openTransactionScreen(store),
            icon: const Icon(Icons.point_of_sale_rounded),
            label: const Text('Transact'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E6C73),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockTile(
    DashboardLowStockItem item, {
    bool showBarcode = false,
  }) {
    final badgeColor = _stockColor(item.stockQty);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.stockQty <= 0
                  ? Icons.error_outline_rounded
                  : Icons.warning_amber_rounded,
              color: badgeColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.category,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                if (showBarcode && item.barcode.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Barcode: ${item.barcode}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _stockLabel(item.stockQty),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0E6C73),
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = _currentRange();

    return Scaffold(
      backgroundColor: const Color(0xFFE6F7F5),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE6F7F5),
              Color(0xFFD5F0EC),
            ],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<DashboardStoreContext>(
            future: _storeFuture,
            builder: (context, storeSnap) {
              if (storeSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (storeSnap.hasError || !storeSnap.hasData) {
                return Center(
                  child: Text(
                    'Failed to load dashboard.\n${storeSnap.error ?? ''}',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final store = storeSnap.data!;

              final txStream = FirebaseFirestore.instance
                  .collection('stores')
                  .doc(store.storeId)
                  .collection('transactions')
                  .where(
                    'createdAt',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
                  )
                  .where(
                    'createdAt',
                    isLessThan: Timestamp.fromDate(range.end),
                  )
                  .orderBy('createdAt', descending: true)
                  .snapshots();

              final itemsStream = FirebaseFirestore.instance
                  .collection('stores')
                  .doc(store.storeId)
                  .collection('items')
                  .snapshots();

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: txStream,
                builder: (context, txSnap) {
                  if (txSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (txSnap.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load sales summary.\n${txSnap.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final docs = txSnap.data?.docs ?? [];
                  final report = _buildReportData(
                    store: store,
                    range: range,
                    docs: docs,
                  );

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: itemsStream,
                    builder: (context, itemSnap) {
                      if (itemSnap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (itemSnap.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load inventory alerts.\n${itemSnap.error}',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      final itemDocs = itemSnap.data?.docs ?? [];
                      final lowStockItems = _buildLowStockItems(itemDocs);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDashboardHeader(store, lowStockItems, report),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Your Dashboard',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildPrimarySalesCard(report, range, store),
                                  const SizedBox(height: 14),
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: _statCard(
                                            title: 'Total Product Sold',
                                            value:
                                                '${report.totalProductsSold}',
                                            smallNote:
                                                report.transactionCount > 0
                                                    ? 'Updated live'
                                                    : 'No sales yet',
                                            icon: Icons.shopping_bag_outlined,
                                            iconColor:
                                                const Color(0xFF0E6C73),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _statCard(
                                            title: 'Low Stock Items',
                                            value: '${lowStockItems.length}',
                                            smallNote: 'Tap to open alerts',
                                            icon:
                                                Icons.warning_amber_rounded,
                                            iconColor: Colors.redAccent,
                                            onTap: () =>
                                                _openNotificationsScreen(
                                              store,
                                              lowStockItems,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Summary Reports',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0E6C73),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.08,
                                              ),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child:
                                              DropdownButton<DashboardFilter>(
                                            value: _selectedFilter,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            items: _filterItems(),
                                            onChanged: (value) {
                                              if (value == null) return;
                                              setState(
                                                () => _selectedFilter = value,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSummaryGraph(docs, range),
                                  if (!allowYearly) ...[
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Yearly view is disabled for now to avoid loading too many transaction records.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  _summaryInfoCard(report),
                                  const SizedBox(height: 14),
                                  _buildSectionTitle(
                                    title: 'Recent Transactions',
                                  ),
                                  const SizedBox(height: 10),
                                  if (docs.isEmpty)
                                    const Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 24,
                                        ),
                                        child: Text(
                                          'No sales found for this selected period.',
                                          style: TextStyle(
                                            color: Colors.black54,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    )
                                  else
                                    ..._buildRecentTransactions(docs),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _summaryInfoCard(DashboardReportData report) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Financial Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0E6C73),
            ),
          ),
          const SizedBox(height: 10),
          _quickRow('Total Sales', _money(report.totalSales)),
          _quickRow('Taxable Sales', _money(report.taxableSales)),
          _quickRow('Tax Collected', _money(report.taxCollected)),
          _quickRow('Cash Sales', _money(report.cashSales)),
          _quickRow('GCash Sales', _money(report.gcashSales)),
          _quickRow('Transactions', '${report.transactionCount}'),
        ],
      ),
    );
  }

  Widget _quickRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String smallNote,
    IconData? icon,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    final child = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: iconColor ?? const Color(0xFF0E6C73),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            smallNote,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: child,
      ),
    );
  }
}