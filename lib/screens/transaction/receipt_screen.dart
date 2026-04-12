import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceiptLine {
  final String name;
  final double price;
  final int qty;

  const ReceiptLine({
    required this.name,
    required this.price,
    required this.qty,
  });

  double get total => price * qty;
}

class ReceiptData {
  final String invoiceId;
  final String invoiceNo;
  final String storeName;
  final DateTime dateTime;
  final String paymentMode;
  final String cashierUid;
  final double subtotal;
  final double taxableSales;
  final bool taxEnabled;
  final String taxName;
  final double taxRate;
  final bool taxInclusive;
  final double tax;
  final double grandTotal;
  final double amountReceived;
  final double change;
  final List<ReceiptLine> items;

  const ReceiptData({
    required this.invoiceId,
    required this.invoiceNo,
    required this.storeName,
    required this.dateTime,
    required this.paymentMode,
    required this.cashierUid,
    required this.subtotal,
    required this.taxableSales,
    required this.taxEnabled,
    required this.taxName,
    required this.taxRate,
    required this.taxInclusive,
    required this.tax,
    required this.grandTotal,
    required this.amountReceived,
    required this.change,
    required this.items,
  });
}

class ReceiptScreen extends StatelessWidget {
  final ReceiptData data;
  final String? receiptUrl;

  const ReceiptScreen({
    super.key,
    required this.data,
    this.receiptUrl,
  });

  String _peso(double value) {
    return NumberFormat.currency(
      locale: 'en_PH',
      symbol: '₱',
      decimalDigits: 2,
    ).format(value);
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM dd, yyyy • hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFFEAF6F4),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFEAF6F4),
        foregroundColor: Colors.black87,
        centerTitle: true,
        title: const Text(
          'Receipt',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      data.storeName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Receipt #${data.invoiceNo}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      dateFmt.format(data.dateTime),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _infoRow('Invoice ID', data.invoiceId),
                  _infoRow('Payment', data.paymentMode),
                  _infoRow(
                    'Cashier UID',
                    data.cashierUid.isEmpty ? '-' : data.cashierUid,
                  ),
                  const Divider(height: 28),
                  const Text(
                    'Items',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...data.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.name} x${item.qty}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _peso(item.total),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 28),
                  _amountRow('Subtotal', _peso(data.subtotal)),
                  _amountRow('Taxable Sales', _peso(data.taxableSales)),
                  if (data.taxEnabled)
                    _amountRow(
                      '${data.taxName} (${data.taxRate.toStringAsFixed(0)}%)',
                      _peso(data.tax),
                    ),
                  if (!data.taxEnabled) _amountRow('Tax', _peso(0)),
                  const SizedBox(height: 6),
                  _amountRow(
                    'Grand Total',
                    _peso(data.grandTotal),
                    bold: true,
                  ),
                  const SizedBox(height: 6),
                  _amountRow('Amount Received', _peso(data.amountReceived)),
                  _amountRow('Change', _peso(data.change)),
                ],
              ),
            ),
            if (receiptUrl != null && receiptUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
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
                child: Column(
                  children: [
                    const Text(
                      'Scan to view receipt',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    QrImageView(
                      data: receiptUrl!,
                      version: QrVersions.auto,
                      size: 220,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      color: bold ? Colors.black : Colors.black87,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}