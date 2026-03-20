import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../transaction/transaction_screen.dart';
import '../transaction/receipt_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _db = FirebaseFirestore.instance;

  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();

  int _navIndex = 1;

  final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
  final timeFmt = DateFormat('h:mm a');

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<String> _requireStoreId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Not logged in.");

    final snap = await _db.collection('users').doc(user.uid).get();
    final storeId = snap.data()?['storeId'] as String?;
    if (storeId == null || storeId.isEmpty) {
      throw Exception("Missing storeId in users/${user.uid}.");
    }
    return storeId;
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

  DateTime get _startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _startOfTomorrow => _startOfToday.add(const Duration(days: 1));

  Stream<double> _todaysSalesStream(String storeId) {
    return _db
        .collection('stores')
        .doc(storeId)
        .collection('transactions')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_startOfToday),
        )
        .where(
          'createdAt',
          isLessThan: Timestamp.fromDate(_startOfTomorrow),
        )
        .snapshots()
        .map((snap) {
      double sum = 0;
      for (final d in snap.docs) {
        final data = d.data();
        sum += _safeToDouble(
          data['grandTotal'],
          fallback: _safeToDouble(data['total']),
        );
      }
      return sum;
    });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _txListStream(
    String storeId,
  ) {
    final col =
        _db.collection('stores').doc(storeId).collection('transactions');

    final q = _searchCtrl.text.trim().toLowerCase();

    if (!_searching || q.isEmpty) {
      return col
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((s) => s.docs);
    }

    return col
        .orderBy('invoiceNoLower')
        .startAt([q])
        .endAt(['$q\uf8ff'])
        .limit(50)
        .snapshots()
        .map((s) {
          final docs = s.docs.toList();

          docs.sort((a, b) {
            final ta = a.data()['createdAt'];
            final tb = b.data()['createdAt'];
            final da = ta is Timestamp ? ta.toDate() : DateTime(1970);
            final db = tb is Timestamp ? tb.toDate() : DateTime(1970);
            return db.compareTo(da);
          });

          return docs;
        });
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _searchCtrl.clear();
    });
  }

  void _openTransactionScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TransactionScreen(isActive: true),
      ),
    );
  }

  Future<void> _openReceipt(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
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

    final subtotal = _safeToDouble(data['subtotal']);
    final tax = _safeToDouble(
      data['tax'],
      fallback: _safeToDouble(data['taxAmount']),
    );

    final taxEnabled =
        (data['taxEnabled'] as bool?) ?? ((tax > 0) ? true : false);

    final taxableSales = _safeToDouble(
      data['taxableSales'],
      fallback: taxEnabled ? (subtotal - tax) : subtotal,
    );

    final receipt = ReceiptData(
      invoiceId: (data['invoiceId'] ?? doc.id).toString(),
      invoiceNo: (data['invoiceNo'] ?? data['invoiceId'] ?? doc.id).toString(),
      storeName: (data['storeName'] ?? 'Business Sale').toString(),
      dateTime: _parseTxDate(data),
      paymentMode:
          (data['paymentMode'] ?? data['paymentMethod'] ?? 'Cash').toString(),
      cashierUid: (data['cashierUid'] ?? '').toString(),
      subtotal: subtotal,
      taxableSales: taxableSales,
      taxEnabled: taxEnabled,
      taxName: (data['taxName'] ?? 'VAT').toString(),
      taxRate: _safeToDouble(data['taxRate'], fallback: 12.0),
      taxInclusive: (data['taxInclusive'] as bool?) ?? true,
      tax: tax,
      grandTotal: _safeToDouble(
        data['grandTotal'],
        fallback: _safeToDouble(data['total']),
      ),
      amountReceived: _safeToDouble(data['amountReceived']),
      change: _safeToDouble(data['change']),
      items: items,
    );

    final receiptUrl = (data['publicReceiptUrl'] as String?)?.trim();

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptScreen(
          data: receipt,
          receiptUrl:
              (receiptUrl != null && receiptUrl.isNotEmpty) ? receiptUrl : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _requireStoreId(),
      builder: (context, storeSnap) {
        if (storeSnap.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${storeSnap.error}')),
          );
        }

        if (!storeSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final storeId = storeSnap.data!;

        return Scaffold(
          backgroundColor: const Color(0xFFEAF5F4),
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFD7F1EE), Color(0xFFEAF5F4)],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _topBar(storeId),
                      const SizedBox(height: 14),
                      _todayCard(storeId),
                      const SizedBox(height: 18),
                      const Text(
                        "Transaction History",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0E6A74),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: StreamBuilder<
                            List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                          stream: _txListStream(storeId),
                          builder: (context, snap) {
                            if (snap.hasError) {
                              return Center(
                                child: Text('Error: ${snap.error}'),
                              );
                            }

                            if (!snap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final docs = snap.data!;
                            if (docs.isEmpty) {
                              return const Center(
                                child: Text('No transactions yet.'),
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.only(bottom: 110),
                              itemCount: docs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) => _txTile(docs[i]),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                _bottomNavOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _topBar(String storeId) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('stores').doc(storeId).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final storeName =
            (data['business_name'] ?? data['name'] ?? 'Store').toString();

        return Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 16,
                    offset: Offset(0, 8),
                    color: Color(0x14000000),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.priority_high, color: Color(0xFF8A2BE2)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                storeName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0A2C33),
                ),
              ),
            ),
            IconButton(
              onPressed: _toggleSearch,
              icon: Icon(_searching ? Icons.close : Icons.search),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.menu),
            ),
          ],
        );
      },
    );
  }

  Widget _todayCard(String storeId) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _searching
                ? TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: "Search invoice…",
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  )
                : StreamBuilder<double>(
                    stream: _todaysSalesStream(storeId),
                    builder: (context, snap) {
                      final value = snap.data ?? 0.0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Today’s Sales",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            money.format(value),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          InkWell(
            onTap: _openTransactionScreen,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(Icons.add, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _txTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();

    final invoiceNo = (d['invoiceNo'] ?? d['invoiceId'] ?? doc.id).toString();
    final method =
        (d['paymentMethod'] ?? d['paymentMode'] ?? 'Cash').toString();
    final status = (d['status'] ?? 'Success').toString();

    final total = _safeToDouble(
      d['grandTotal'],
      fallback: _safeToDouble(d['total']),
    );

    final dt = _parseTxDate(d);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFD6EFEC),
          child: Icon(Icons.receipt, color: Color(0xFF2E7D78)),
        ),
        title: Text(
          "Invoice #$invoiceNo",
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                method,
                style: const TextStyle(color: Colors.black54),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              timeFmt.format(dt),
              style: const TextStyle(color: Colors.black38),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money.format(total),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              status,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2E7D78),
              ),
            ),
          ],
        ),
        onTap: () => _openReceipt(doc),
      ),
    );
  }

  Widget _bottomNavOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 14,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFF0A3B46),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 20,
                  offset: Offset(0, 12),
                  color: Color(0x1A000000),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _openTransactionScreen,
              icon: const Icon(Icons.receipt_long, color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 22),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFF0A3B46),
              borderRadius: BorderRadius.circular(40),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 22,
                  offset: Offset(0, 12),
                  color: Color(0x1A000000),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _navIcon(Icons.home_outlined, 0),
                _navIcon(Icons.receipt_long, 1),
                const SizedBox(width: 52),
                _navIcon(Icons.inventory_2_outlined, 2),
                _navIcon(Icons.person_outline, 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, int index) {
    final active = _navIndex == index;

    return InkWell(
      onTap: () => setState(() => _navIndex = index),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          icon,
          color: active ? const Color(0xFF0A3B46) : Colors.white,
        ),
      ),
    );
  }
}
