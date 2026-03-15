import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PublicReceiptScreen extends StatelessWidget {
  final String? token;

  const PublicReceiptScreen({
    super.key,
    this.token,
  });

  String? _resolveToken() {
    final directToken = token?.trim();
    if (directToken != null && directToken.isNotEmpty) {
      return directToken;
    }

    final queryToken = Uri.base.queryParameters['token']?.trim();
    if (queryToken != null && queryToken.isNotEmpty) {
      return queryToken;
    }

    final fragment = Uri.base.fragment.trim();
    if (fragment.isEmpty) return null;

    final normalized = fragment.startsWith('/') ? fragment : '/$fragment';
    final fragmentUri = Uri.tryParse(normalized);

    final fragmentToken = fragmentUri?.queryParameters['token']?.trim();
    if (fragmentToken != null && fragmentToken.isNotEmpty) {
      return fragmentToken;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final receiptToken = _resolveToken();

    if (receiptToken == null || receiptToken.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('Invalid receipt link.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('E-Receipt')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('public_receipts')
            .doc(receiptToken)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Receipt not found.'),
            );
          }

          final data = snapshot.data!.data()!;
          final items = (data['items'] as List?) ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                (data['storeName'] ?? 'Store').toString(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Receipt No: ${(data['receiptNumber'] ?? '-').toString()}'),
              Text('Cashier: ${(data['cashierName'] ?? '-').toString()}'),
              Text('Payment: ${(data['paymentMethod'] ?? '-').toString()}'),
              const SizedBox(height: 16),
              const Text(
                'Items',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Divider(),
              ...items.map((item) {
                final map = Map<String, dynamic>.from(item as Map);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text((map['name'] ?? '').toString()),
                  subtitle: Text('Qty: ${(map['qty'] ?? 0).toString()}'),
                  trailing: Text(
                    '₱ ${_toDouble(map['total']).toStringAsFixed(2)}',
                  ),
                );
              }),
              const Divider(height: 32),
              _totalRow('Subtotal', data['subtotal']),
              _totalRow('Tax', data['tax']),
              _totalRow(
                'Total',
                data['total'],
                isBold: true,
              ),
              _totalRow('Amount Paid', data['amountPaid']),
              _totalRow('Change', data['change']),
            ],
          );
        },
      ),
    );
  }

  Widget _totalRow(String label, dynamic value, {bool isBold = false}) {
    final amount = _toDouble(value).toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '₱ $amount',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
