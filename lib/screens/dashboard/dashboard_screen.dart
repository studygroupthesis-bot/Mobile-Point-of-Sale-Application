import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  const DashboardStoreContext({
    required this.storeId,
    required this.storeName,
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

class DashboardSummaryData {
  final String storeName;
  final String filterLabel;
  final String rangeLabel;
  final double totalSales;
  final int transactionCount;
  final int totalProductsSold;
  final DateTime generatedAt;

  const DashboardSummaryData({
    required this.storeName,
    required this.filterLabel,
    required this.rangeLabel,
    required this.totalSales,
    required this.transactionCount,
    required this.totalProductsSold,
    required this.generatedAt,
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Keep false for now to avoid heavy yearly reads
  static const bool allowYearly = false;

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

    final storeName = (storeSnap.data()?['name'] ?? 'My Store').toString();

    return DashboardStoreContext(
      storeId: storeId,
      storeName: storeName,
    );
  }

  DashboardRange _currentRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Monday-based week
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

  Future<void> _handleExport(
    DashboardExportAction action,
    DashboardSummaryData summary,
  ) async {
    switch (action) {
      case DashboardExportAction.pdf:
        await _exportSummaryPdf(summary);
        break;
      case DashboardExportAction.csv:
        await _copySummaryCsv(summary);
        break;
    }
  }

  Future<void> _exportSummaryPdf(DashboardSummaryData summary) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'Sales Summary Report',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Store: ${summary.storeName}'),
          pw.Text('Filter: ${summary.filterLabel}'),
          pw.Text('Range: ${summary.rangeLabel}'),
          pw.Text('Generated: ${summary.generatedAt}'),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text('Total Sales: PHP ${summary.totalSales.toStringAsFixed(2)}'),
          pw.Text('Transactions: ${summary.transactionCount}'),
          pw.Text('Total Products Sold: ${summary.totalProductsSold}'),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
    );
  }

  Future<void> _copySummaryCsv(DashboardSummaryData summary) async {
    final csv = [
      'Store,Filter,Range,Total Sales,Transactions,Total Products Sold,Generated At',
      '"${summary.storeName}","${summary.filterLabel}","${summary.rangeLabel}","${summary.totalSales.toStringAsFixed(2)}","${summary.transactionCount}","${summary.totalProductsSold}","${summary.generatedAt.toIso8601String()}"',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: csv));

    if (!mounted) return;
    _showSnack('CSV summary copied to clipboard.');
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
          final amount = (data['grandTotal'] as num?)?.toDouble() ?? 0;

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
          final amount = (data['grandTotal'] as num?)?.toDouble() ?? 0;

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
          final amount = (data['grandTotal'] as num?)?.toDouble() ?? 0;

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
            'Sales',
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

  @override
  Widget build(BuildContext context) {
    final range = _currentRange();

    return Scaffold(
      backgroundColor: const Color(0xFFD47F82),
      body: SafeArea(
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

            return Center(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE6F7F5),
                      Color(0xFFD5F0EC),
                    ],
                  ),
                ),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

                    final totalSales = docs.fold<double>(
                      0,
                      (sum, doc) =>
                          sum +
                          ((doc.data()['grandTotal'] as num?)?.toDouble() ?? 0),
                    );

                    final transactionCount = docs.length;
                    final totalProductsSold = _sumProducts(docs);

                    final summary = DashboardSummaryData(
                      storeName: store.storeName,
                      filterLabel: _selectedFilterLabel(),
                      rangeLabel: range.subtitle,
                      totalSales: totalSales,
                      transactionCount: transactionCount,
                      totalProductsSold: totalProductsSold,
                      generatedAt: DateTime.now(),
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.storefront,
                                color: Color(0xFFB12A87),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                store.storeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.search),
                            ),
                            PopupMenuButton<DashboardExportAction>(
                              tooltip: 'Export summary',
                              icon: const Icon(Icons.note_alt_outlined),
                              onSelected: (value) async {
                                await _handleExport(value, summary);
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
                        const SizedBox(height: 18),

                        const Text(
                          'Your Dashboard',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Top total sales card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
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
                                      _money(totalSales),
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
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.add, size: 28),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Stats row
                        Row(
                          children: [
                            Expanded(
                              child: _statCard(
                                title: 'Total Product Sold',
                                value: '$totalProductsSold',
                                smallNote: transactionCount > 0
                                    ? 'Updated live'
                                    : 'No sales yet',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _statCard(
                                title: 'Transactions',
                                value: '$transactionCount',
                                smallNote: 'For selected period',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Summary header + dropdown
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<DashboardFilter>(
                                  value: _selectedFilter,
                                  borderRadius: BorderRadius.circular(12),
                                  items: _filterItems(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _selectedFilter = value);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Graph
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

                        Expanded(
                          child: docs.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No sales found for this selected period.',
                                    style: TextStyle(color: Colors.black54),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: docs.length > 5 ? 5 : docs.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final data = docs[index].data();
                                    final invoiceId =
                                        (data['invoiceId'] ?? docs[index].id)
                                            .toString();
                                    final amount = (data['grandTotal'] as num?)
                                            ?.toDouble() ??
                                        0;
                                    final paymentMode =
                                        (data['paymentMode'] ?? 'Cash')
                                            .toString();

                                    return Container(
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
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Invoice #$invoiceId',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String smallNote,
  }) {
    return Container(
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
          Text(title, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            smallNote,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
