import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../auth/widget/receipt_qr_card.dart';

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

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final dd = dt.day.toString().padLeft(2, '0');
    final mon = months[dt.month - 1];
    final yyyy = dt.year.toString();

    int hour = dt.hour;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;

    final hh = hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');

    return '$dd-$mon-$yyyy $hh:$mm $ampm';
  }

  String _money(double v) => '₱ ${v.toStringAsFixed(2)}';

  String _shortCashierUid(String uid) {
    if (uid.length <= 6) return uid;
    return uid.substring(0, 6);
  }

  String _formatRate(double value) {
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  String _taxLabel() {
    return data.taxInclusive
        ? '${data.taxName} (${_formatRate(data.taxRate)}% incl.)'
        : '${data.taxName} (${_formatRate(data.taxRate)}%)';
  }

  String _shareText() {
    final b = StringBuffer();
    b.writeln(data.storeName);
    b.writeln('Invoice #${data.invoiceNo}');
    b.writeln(_formatDateTime(data.dateTime));
    b.writeln('Payment: ${data.paymentMode}');
    b.writeln('Cashier: ${data.cashierUid}');
    b.writeln('---');

    for (final it in data.items) {
      b.writeln('${it.name} x${it.qty}  ${_money(it.total)}');
    }

    b.writeln('---');
    b.writeln('Subtotal: ${_money(data.subtotal)}');

    if (data.taxEnabled) {
      if (data.taxInclusive) {
        b.writeln('Taxable Sales: ${_money(data.taxableSales)}');
      }
      b.writeln('${_taxLabel()}: ${_money(data.tax)}');
    }

    b.writeln('Grand Total: ${_money(data.grandTotal)}');

    if (data.paymentMode.toLowerCase() == 'cash') {
      b.writeln('Received: ${_money(data.amountReceived)}');
      b.writeln('Change: ${_money(data.change)}');
    }

    if ((receiptUrl ?? '').trim().isNotEmpty) {
      b.writeln('---');
      b.writeln('View receipt: $receiptUrl');
    }

    b.writeln('Thank you! Visit again!');
    return b.toString();
  }

  Future<void> _handleShare(BuildContext context) async {
    final hasReceiptUrl = (receiptUrl ?? '').trim().isNotEmpty;

    if (hasReceiptUrl) {
      await SharePlus.instance.share(
        ShareParams(
          subject: 'Receipt ${data.invoiceNo}',
          text: 'Thank you for your purchase.\n\n'
              'Receipt #${data.invoiceNo}\n'
              'View your receipt here:\n$receiptUrl',
        ),
      );
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: _shareText()),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt copied to clipboard.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasReceiptUrl = (receiptUrl ?? '').trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF7CBD0),
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
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
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Receipt',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle,
                      color: Color(0xFF00A88B),
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              'Invoice #${data.invoiceNo}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Center(
                            child: Text(
                              _formatDateTime(data.dateTime),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _headerCell('P Mode'),
                              _headerCell('Items'),
                              _headerCell('U#'),
                              _headerCell('Amount'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _valueCell(data.paymentMode),
                              _valueCell('${data.items.length}'),
                              _valueCell(_shortCashierUid(data.cashierUid)),
                              _valueCell(_money(data.grandTotal)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          const Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'Name',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Price',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'Qty',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Total',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          data.items.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      'No items',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: data.items.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (context, index) {
                                    final it = data.items[index];
                                    return Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            it.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            _money(it.price),
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '${it.qty}',
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            _money(it.total),
                                            textAlign: TextAlign.end,
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                          const Divider(height: 18),
                          _kv('Sub total', _money(data.subtotal)),
                          if (data.taxEnabled && data.taxInclusive)
                            _kv('Taxable Sales', _money(data.taxableSales)),
                          if (data.taxEnabled)
                            _kv(_taxLabel(), _money(data.tax)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD5F0EC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _kv(
                              'Grand Total',
                              _money(data.grandTotal),
                              bold: true,
                            ),
                          ),
                          if (data.paymentMode.toLowerCase() == 'cash') ...[
                            const SizedBox(height: 8),
                            _kv('Received', _money(data.amountReceived)),
                            _kv('Change', _money(data.change)),
                          ],
                          const SizedBox(height: 10),
                          const Center(
                            child: Text(
                              'Thank you! Visit again!',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          if (hasReceiptUrl) ...[
                            const SizedBox(height: 14),
                            ReceiptQrCard(
                              receiptUrl: receiptUrl!,
                              receiptNumber: data.invoiceNo,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A88B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Print: TODO')),
                      );
                    },
                    child: const Text('PRINT'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A88B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _handleShare(context),
                    child: Text(hasReceiptUrl ? 'SHARE RECEIPT LINK' : 'SHARE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: style),
          Text(v, style: style),
        ],
      ),
    );
  }

  static Widget _headerCell(String t) {
    return Expanded(
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static Widget _valueCell(String t) {
    return Expanded(
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}
