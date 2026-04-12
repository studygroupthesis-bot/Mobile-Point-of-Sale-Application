import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PublicReceiptScreen extends StatelessWidget {
  final String storeId;
  final String transactionId;

  const PublicReceiptScreen({
    super.key,
    required this.storeId,
    required this.transactionId,
  });

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0.0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _peso(dynamic value) {
    return '₱${_toDouble(value).toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('public_receipts')
        .doc(transactionId)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFEAF6F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF6F4),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Public Receipt',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final data = snap.data?.data();
          if (data == null) {
            return const Center(child: Text('Receipt not found.'));
          }

          final items = (data['items'] as List?) ?? const [];
          final storeName = (data['storeName'] ?? 'Store').toString();
          final receiptNumber =
              (data['invoiceNo'] ?? data['receiptNumber'] ?? transactionId)
                  .toString();

          final subtotal = _toDouble(data['subtotal']);
          final tax = _toDouble(data['tax']);
          final total = _toDouble(data['total'] ?? data['grandTotal']);
          final amountPaid = _toDouble(
            data['amountPaid'] ?? data['amountReceived'],
          );
          final change = _toDouble(data['change']);
          final paymentMethod =
              (data['paymentMethod'] ?? data['paymentMode'] ?? 'Cash')
                  .toString();
          final cashierName =
              (data['cashierName'] ?? data['cashierUid'] ?? '-').toString();

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  storeName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Receipt #$receiptNumber',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Items',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...items.map((item) {
                            final map = Map<String, dynamic>.from(item as Map);
                            final name = (map['name'] ?? 'Item').toString();
                            final qty = _toInt(map['qty']);
                            final price = _toDouble(map['price']);
                            final lineTotal = _toDouble(
                              map['lineTotal'] ?? map['total'] ?? (price * qty),
                            );

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$name x$qty',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    '₱${price.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '₱${lineTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          _summaryRow('Subtotal', _peso(subtotal)),
                          _summaryRow(
                            (data['taxName'] ?? 'Tax').toString(),
                            _peso(tax),
                          ),
                          _summaryRow('Total', _peso(total), bold: true),
                          const SizedBox(height: 8),
                          _summaryRow('Amount Paid', _peso(amountPaid)),
                          _summaryRow('Change', _peso(change)),
                          const SizedBox(height: 12),
                          Text(
                            'Payment Method: $paymentMethod',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cashier: $cashierName',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
