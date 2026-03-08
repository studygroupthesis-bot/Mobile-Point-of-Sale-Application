import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProductBatchDetailsScreen extends StatefulWidget {
  final String storeId;
  final String itemId;
  final String productName;

  const ProductBatchDetailsScreen({
    super.key,
    required this.storeId,
    required this.itemId,
    required this.productName,
  });

  @override
  State<ProductBatchDetailsScreen> createState() =>
      _ProductBatchDetailsScreenState();
}

class _ProductBatchDetailsScreenState extends State<ProductBatchDetailsScreen> {
  int _readInt(Map<String, dynamic> d, List<String> keys, {int fallback = 0}) {
    for (final k in keys) {
      final v = d[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return p;
      }
    }
    return fallback;
  }

  double _readDouble(
    Map<String, dynamic> d,
    List<String> keys, {
    double fallback = 0,
  }) {
    for (final k in keys) {
      final v = d[k];
      if (v is double) return v;
      if (v is num) return v.toDouble();
      if (v is String) {
        final p = double.tryParse(v);
        if (p != null) return p;
      }
    }
    return fallback;
  }

  String _readString(
    Map<String, dynamic> d,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final k in keys) {
      final v = d[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return fallback;
  }

  DateTime? _readDate(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
    }
    return null;
  }

  String _money(double value) {
    return '₱${value.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$month/$day/$year';
  }

  String _statusLabel(DateTime? expiryDate, int qty) {
    if (qty <= 0) return 'Out';
    if (expiryDate == null) return 'No expiry';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

    if (exp.isBefore(today)) return 'Expired';

    final diff = exp.difference(today).inDays;
    if (diff <= 7) return 'Near expiry';

    return 'Good';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Expired':
        return Colors.red.shade100;
      case 'Near expiry':
        return Colors.orange.shade100;
      case 'Out':
        return Colors.grey.shade300;
      case 'No expiry':
        return Colors.blueGrey.shade100;
      default:
        return Colors.green.shade100;
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'Expired':
        return Colors.red.shade800;
      case 'Near expiry':
        return Colors.orange.shade800;
      case 'Out':
        return Colors.grey.shade800;
      case 'No expiry':
        return Colors.blueGrey.shade800;
      default:
        return Colors.green.shade800;
    }
  }

  Widget _infoRow({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('stores')
        .doc(widget.storeId)
        .collection('stock_logs')
        .where('itemId', isEqualTo: widget.itemId)
        .where('type', isEqualTo: 'stock_in')
        .orderBy('created_at', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFD78383),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD78383),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Product Batch Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE6E6E6),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFD8F0EC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This shows the stock-in history of the selected product by batch code, date received, and expiry date.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Firestore error:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('No batch records found.'),
                      );
                    }

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final data = docs[index].data();

                        final batchCode = _readString(
                          data,
                          ['batchCode'],
                          fallback: 'Batch ${index + 1}',
                        );

                        final stockInCode = _readString(data, ['stockInCode']);
                        final receivedDate =
                            _readDate(data, ['receivedDate', 'created_at']);
                        final expiryDate = _readDate(data, ['expiryDate']);
                        final qtyAdded = _readInt(
                          data,
                          ['quantity', 'qtyAdded', 'quantityAdded'],
                        );

                        // Since you are using stock_logs as the source,
                        // remaining quantity is not directly tracked here.
                        // So we use quantity as the display quantity for now.
                        final qtyRemaining = _readInt(
                          data,
                          ['remainingQty', 'qtyRemaining', 'quantity'],
                          fallback: qtyAdded,
                        );

                        final cost = _readDouble(
                          data,
                          ['costPrice', 'cost', 'unitCost'],
                        );

                        final encodedByName =
                            _readString(data, ['encodedByName']);
                        final encodedByEmail =
                            _readString(data, ['encodedByEmail']);
                        final notes = _readString(data, ['notes']);

                        final status = _statusLabel(expiryDate, qtyRemaining);

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      batchCode,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: _statusTextColor(status),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (stockInCode.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    'Stock In Code: $stockInCode',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              _infoRow(
                                label: 'Received Date',
                                value: _formatDate(receivedDate),
                              ),
                              _infoRow(
                                label: 'Expiry Date',
                                value: _formatDate(expiryDate),
                              ),
                              _infoRow(
                                label: 'Qty Added',
                                value: qtyAdded.toString(),
                              ),
                              _infoRow(
                                label: 'Qty Remaining',
                                value: qtyRemaining.toString(),
                              ),
                              _infoRow(
                                label: 'Unit Cost',
                                value: _money(cost),
                              ),
                              _infoRow(
                                label: 'Encoded By',
                                value: encodedByName.isNotEmpty
                                    ? encodedByName
                                    : '-',
                              ),
                              if (encodedByEmail.isNotEmpty)
                                _infoRow(
                                  label: 'Encoder Email',
                                  value: encodedByEmail,
                                ),
                              if (notes.isNotEmpty)
                                _infoRow(
                                  label: 'Notes',
                                  value: notes,
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
