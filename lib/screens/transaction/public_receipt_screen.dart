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

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('public_receipts')
        .doc(transactionId)
        .snapshots();

    return Scaffold(
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

          return Center(
            child: Text(
              'Receipt #${data['invoiceNo'] ?? transactionId}',
            ),
          );
        },
      ),
    );
  }
}
