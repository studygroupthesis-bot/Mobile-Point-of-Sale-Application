import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      return DateFormat('MMM dd, yyyy • hh:mm a').format(value.toDate());
    }
    return '-';
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
      appBar: AppBar(
        title: const Text('Public Receipt'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error: ${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snap.data?.data();
          if (data == null) {
            return const Center(child: Text('Receipt not found.'));
          }

          if (data['isActive'] != true) {
            return const Center(child: Text('Receipt is not active.'));
          }

          final items = (data['items'] as List?) ?? const [];
          final storeName = (data['storeName'] ?? 'Store').toString();
          final receiptNumber =
              (data['invoiceNo'] ?? data['receiptNumber'] ?? transactionId)
                  .toString();

          final subtotal = _toDouble(data['subtotal']);
          final taxableSales = _toDouble(data['taxableSales'] ?? subtotal);
          final tax = _toDouble(data['tax']);
          final total = _toDouble(data['grandTotal'] ?? data['total']);
          final amountReceived =
              _toDouble(data['amountReceived'] ?? data['amountPaid']);
          final change = _toDouble(data['change']);
          final paymentMethod =
              (data['paymentMethod'] ?? data['paymentMode'] ?? 'Cash')
                  .toString();
          final cashierName =
              (data['cashierName'] ?? data['cashierUid'] ?? '-').toString();
          final createdAt = _formatDate(data['createdAt']);

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
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
                                const SizedBox(height: 4),
                                Text(
                                  createdAt,
                                  style: const TextStyle(fontSize: 13),
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
                            final unitPrice = _toDouble(map['price']);
                            final lineTotal = _toDouble(
                              map['total'] ?? (unitPrice * qty),
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
                                    '₱${unitPrice.toStringAsFixed(2)}',
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
                          }).toList(),
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          _summaryRow('Subtotal', _peso(subtotal)),
                          _summaryRow('Taxable Sales', _peso(taxableSales)),
                          _summaryRow(
                            (data['taxName'] ?? 'Tax').toString(),
                            _peso(tax),
                          ),
                          _summaryRow('Grand Total', _peso(total), bold: true),
                          const SizedBox(height: 8),
                          _summaryRow('Amount Received', _peso(amountReceived)),
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