import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../transaction/receipt_screen.dart';

class StoreContext {
  final String storeId;
  final String storeName;

  const StoreContext({
    required this.storeId,
    required this.storeName,
  });
}

class TransactionHistory extends StatefulWidget {
  const TransactionHistory({super.key});

  @override
  State<TransactionHistory> createState() =>
      _TransactionHistoryDailyScreenState();
}

class _TransactionHistoryDailyScreenState extends State<TransactionHistory> {
  late final Future<StoreContext> _storeContextFuture;
  DateTime _selectedDate = _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _storeContextFuture = _loadStoreContext();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  double _safeToDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0.0;
  }

  int _safeToInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Future<StoreContext> _loadStoreContext() async {
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

    final storeName = (storeSnap.data()?['name'] ?? 'Business Sale').toString();

    return StoreContext(
      storeId: storeId,
      storeName: storeName,
    );
  }

  Timestamp get _startOfDayTs => Timestamp.fromDate(_selectedDate);

  Timestamp get _endOfDayTs =>
      Timestamp.fromDate(_selectedDate.add(const Duration(days: 1)));

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return now.year == d.year && now.month == d.month && now.day == d.day;
  }

  String _money(num? v) => '₱ ${(v ?? 0).toDouble().toStringAsFixed(2)}';

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatDateChip(DateTime d) {
    return '${_two(d.month)}/${_two(d.day)}/${d.year.toString().substring(2)}';
  }

  String _formatHeaderTitle() {
    if (_isToday(_selectedDate)) return "Today's Sales";
    return 'Sales for ${_formatLongDate(_selectedDate)}';
  }

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

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = _dateOnly(picked);
    });
  }

  Future<void> _openReceipt({
    required StoreContext store,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) async {
    final data = doc.data();

    final rawItems = (data['items'] as List?) ?? [];
    final items = rawItems.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return ReceiptLine(
        name: (map['name'] ?? '').toString(),
        price: _safeToDouble(map['price']),
        qty: _safeToInt(map['qty']),
      );
    }).toList();

    final receipt = ReceiptData(
      invoiceId: (data['invoiceId'] ?? doc.id).toString(),
      invoiceNo: (data['invoiceNo'] ?? data['invoiceId'] ?? doc.id).toString(),
      storeName: (data['storeName'] ?? store.storeName).toString(),
      dateTime: _parseTxDate(data),
      paymentMode:
          (data['paymentMode'] ?? data['paymentMethod'] ?? 'Cash').toString(),
      cashierUid: (data['cashierUid'] ?? '').toString(),
      subtotal: _safeToDouble(data['subtotal']),
      tax: _safeToDouble(data['tax']),
      grandTotal: _safeToDouble(data['grandTotal']),
      amountReceived: _safeToDouble(data['amountReceived']),
      change: _safeToDouble(data['change']),
      items: items,
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptScreen(data: receipt),
      ),
    );
  }

  Widget _buildTransactionTile({
    required StoreContext store,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data();
    final date = _parseTxDate(data);

    final invoiceNo =
        (data['invoiceNo'] ?? data['invoiceId'] ?? doc.id).toString();
    final paymentMode =
        (data['paymentMode'] ?? data['paymentMethod'] ?? 'Cash').toString();
    final amount = _safeToDouble(data['grandTotal']);
    final status = (data['status'] ?? 'Success').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openReceipt(store: store, doc: doc),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFB8DFDA),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Color(0xFF0E6C73),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice #$invoiceNo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    paymentMode,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money(amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(date),
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: const TextStyle(
                    color: Color(0xFF0E6C73),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD47F82),
      body: SafeArea(
        child: FutureBuilder<StoreContext>(
          future: _storeContextFuture,
          builder: (context, storeSnap) {
            if (storeSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (storeSnap.hasError || !storeSnap.hasData) {
              return Center(
                child: Text(
                  'Failed to load transaction history.\n${storeSnap.error ?? ''}',
                  textAlign: TextAlign.center,
                ),
              );
            }

            final store = storeSnap.data!;

            final stream = FirebaseFirestore.instance
                .collection('stores')
                .doc(store.storeId)
                .collection('transactions')
                .where('createdAt', isGreaterThanOrEqualTo: _startOfDayTs)
                .where('createdAt', isLessThan: _endOfDayTs)
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new),
                        ),
                        const Expanded(
                          child: Text(
                            'Transaction History',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: stream,
                        builder: (context, txSnap) {
                          if (txSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (txSnap.hasError) {
                            return Center(
                              child: Text(
                                'Failed to load transactions.\n${txSnap.error}',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          final docs = txSnap.data?.docs ?? [];

                          final totalSales = docs.fold<double>(
                            0,
                            (sum, doc) =>
                                sum + _safeToDouble(doc.data()['grandTotal']),
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatHeaderTitle(),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _money(totalSales),
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
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
                                      'Transaction History',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 20,
                                        color: Color(0xFF0E6C73),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _pickDate,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.black12,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            _formatDateChip(_selectedDate),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.keyboard_arrow_down,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: docs.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No transactions for ${_formatLongDate(_selectedDate)}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: docs.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          return _buildTransactionTile(
                                            store: store,
                                            doc: docs[index],
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
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
}
