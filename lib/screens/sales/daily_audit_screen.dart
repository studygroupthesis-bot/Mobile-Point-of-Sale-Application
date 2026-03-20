import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DailyAuditScreen extends StatefulWidget {
  final String storeId;
  final String storeName;
  final DateTime selectedDate;

  const DailyAuditScreen({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.selectedDate,
  });

  @override
  State<DailyAuditScreen> createState() => _DailyAuditScreenState();
}

class _DailyAuditScreenState extends State<DailyAuditScreen> {
  bool _saving = false;

  DateTime get _dateOnly => DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
      );

  Timestamp get _startOfDayTs => Timestamp.fromDate(_dateOnly);

  Timestamp get _endOfDayTs =>
      Timestamp.fromDate(_dateOnly.add(const Duration(days: 1)));

  double _safeToDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _safeToInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  DateTime _parseTxDate(Map<String, dynamic> data) {
    final ts = data['createdAt'];
    if (ts is Timestamp) return ts.toDate();

    final local = data['createdAtLocal'];
    if (local is String) {
      final parsed = DateTime.tryParse(local);
      if (parsed != null) return parsed;
    }

    return DateTime.now();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _money(double v) => '₱ ${v.toStringAsFixed(2)}';

  String _dateKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  String _formatLongDate(DateTime d) {
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
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatTime(DateTime d) {
    int hour = d.hour;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '${_two(hour)}:${_two(d.minute)} $suffix';
  }

  Future<void> _saveAudit(DailyAuditTotals totals) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .collection('daily_audits')
          .doc(_dateKey(_dateOnly))
          .set({
        'storeId': widget.storeId,
        'storeName': widget.storeName,
        'auditDate': _dateKey(_dateOnly),
        'auditDateTs': Timestamp.fromDate(_dateOnly),
        'generatedAt': FieldValue.serverTimestamp(),
        'generatedByUid': uid,
        'grossSales': totals.grossSales,
        'subtotalSales': totals.subtotalSales,
        'taxableSales': totals.taxableSales,
        'taxCollected': totals.taxCollected,
        'nonTaxSales': totals.nonTaxSales,
        'cashSales': totals.cashSales,
        'gcashSales': totals.gcashSales,
        'otherSales': totals.otherSales,
        'cashReceived': totals.cashReceived,
        'changeGiven': totals.changeGiven,
        'netCashKept': totals.netCashKept,
        'transactionCount': totals.transactionCount,
        'successCount': totals.successCount,
        'nonSuccessCount': totals.nonSuccessCount,
        'itemLineCount': totals.itemLineCount,
        'quantitySold': totals.quantitySold,
        'firstInvoiceNo': totals.firstInvoiceNo,
        'lastInvoiceNo': totals.lastInvoiceNo,
        'firstTransactionAtLocal': totals.firstTransactionAt?.toIso8601String(),
        'lastTransactionAtLocal': totals.lastTransactionAt?.toIso8601String(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily audit saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save audit: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  DailyAuditTotals _computeTotals(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    double grossSales = 0;
    double subtotalSales = 0;
    double taxableSales = 0;
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

    DateTime? firstTransactionAt;
    DateTime? lastTransactionAt;
    String? firstInvoiceNo;
    String? lastInvoiceNo;

    final sortedDocs = docs.toList()
      ..sort((a, b) {
        final da = _parseTxDate(a.data());
        final db = _parseTxDate(b.data());
        return da.compareTo(db);
      });

    for (final doc in sortedDocs) {
      final data = doc.data();

      final status = (data['status'] ?? 'Success').toString();
      final isSuccess = status.toLowerCase() == 'success';

      final total = _safeToDouble(
        data['grandTotal'],
        fallback: _safeToDouble(data['total']),
      );
      final subtotal = _safeToDouble(data['subtotal']);
      final tax = _safeToDouble(
        data['tax'],
        fallback: _safeToDouble(data['taxAmount']),
      );

      final taxEnabled =
          (data['taxEnabled'] as bool?) ?? ((tax > 0) ? true : false);

      final taxable = _safeToDouble(
        data['taxableSales'],
        fallback: taxEnabled ? (subtotal - tax) : subtotal,
      );

      final paymentMode =
          (data['paymentMode'] ?? data['paymentMethod'] ?? 'Cash')
              .toString()
              .toLowerCase();

      final amountReceived = _safeToDouble(data['amountReceived']);
      final change = _safeToDouble(data['change']);
      final date = _parseTxDate(data);
      final invoiceNo =
          (data['invoiceNo'] ?? data['invoiceId'] ?? doc.id).toString();

      final rawItems = (data['items'] as List?) ?? [];
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

      grossSales += total;
      subtotalSales += subtotal;

      if (taxEnabled) {
        taxableSales += taxable;
        taxCollected += tax;
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

      firstTransactionAt ??= date;
      firstInvoiceNo ??= invoiceNo;
      lastTransactionAt = date;
      lastInvoiceNo = invoiceNo;
    }

    return DailyAuditTotals(
      grossSales: grossSales,
      subtotalSales: subtotalSales,
      taxableSales: taxableSales,
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
      firstTransactionAt: firstTransactionAt,
      lastTransactionAt: lastTransactionAt,
      firstInvoiceNo: firstInvoiceNo,
      lastInvoiceNo: lastInvoiceNo,
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('stores')
        .doc(widget.storeId)
        .collection('transactions')
        .where('createdAt', isGreaterThanOrEqualTo: _startOfDayTs)
        .where('createdAt', isLessThan: _endOfDayTs)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFD47F82),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Daily Audit / Z-Reading'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return Center(
                child: Text(
                  'Failed to load audit data.\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }

            final docs = snap.data?.docs ?? [];
            final totals = _computeTotals(docs);

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.storeName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatLongDate(_dateOnly),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _kpiCard('Gross Sales', _money(totals.grossSales)),
                        const SizedBox(width: 10),
                        _kpiCard(
                          'Transactions',
                          '${totals.transactionCount}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _kpiCard('Qty Sold', '${totals.quantitySold}'),
                        const SizedBox(width: 10),
                        _kpiCard('Tax Collected', _money(totals.taxCollected)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _sectionCard(
                              title: 'Sales & Tax Summary',
                              children: [
                                _summaryRow(
                                  'Gross Sales',
                                  _money(totals.grossSales),
                                ),
                                _summaryRow(
                                  'Subtotal Sales',
                                  _money(totals.subtotalSales),
                                ),
                                _summaryRow(
                                  'Taxable Sales',
                                  _money(totals.taxableSales),
                                ),
                                _summaryRow(
                                  'Tax Collected',
                                  _money(totals.taxCollected),
                                ),
                                _summaryRow(
                                  'Non-Tax Sales',
                                  _money(totals.nonTaxSales),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _sectionCard(
                              title: 'Payment Summary',
                              children: [
                                _summaryRow(
                                  'Cash Sales',
                                  _money(totals.cashSales),
                                ),
                                _summaryRow(
                                  'GCash Sales',
                                  _money(totals.gcashSales),
                                ),
                                _summaryRow(
                                  'Other Sales',
                                  _money(totals.otherSales),
                                ),
                                _summaryRow(
                                  'Cash Received',
                                  _money(totals.cashReceived),
                                ),
                                _summaryRow(
                                  'Change Given',
                                  _money(totals.changeGiven),
                                ),
                                _summaryRow(
                                  'Net Cash Kept',
                                  _money(totals.netCashKept),
                                  bold: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _sectionCard(
                              title: 'Audit Trail',
                              children: [
                                _summaryRow(
                                  'Successful Transactions',
                                  '${totals.successCount}',
                                ),
                                _summaryRow(
                                  'Non-Success Transactions',
                                  '${totals.nonSuccessCount}',
                                ),
                                _summaryRow(
                                  'Item Lines',
                                  '${totals.itemLineCount}',
                                ),
                                _summaryRow(
                                  'Quantity Sold',
                                  '${totals.quantitySold}',
                                ),
                                _summaryRow(
                                  'First Invoice',
                                  totals.firstInvoiceNo ?? '-',
                                ),
                                _summaryRow(
                                  'Last Invoice',
                                  totals.lastInvoiceNo ?? '-',
                                ),
                                _summaryRow(
                                  'First Transaction',
                                  totals.firstTransactionAt != null
                                      ? _formatTime(totals.firstTransactionAt!)
                                      : '-',
                                ),
                                _summaryRow(
                                  'Last Transaction',
                                  totals.lastTransactionAt != null
                                      ? _formatTime(totals.lastTransactionAt!)
                                      : '-',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : () => _saveAudit(totals),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A88B),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(_saving ? 'SAVING...' : 'SAVE DAILY AUDIT'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0E6C73),
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class DailyAuditTotals {
  final double grossSales;
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

  final DateTime? firstTransactionAt;
  final DateTime? lastTransactionAt;
  final String? firstInvoiceNo;
  final String? lastInvoiceNo;

  const DailyAuditTotals({
    required this.grossSales,
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
    required this.firstTransactionAt,
    required this.lastTransactionAt,
    required this.firstInvoiceNo,
    required this.lastInvoiceNo,
  });
}
