import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final String storeName;
  final DateTime dateTime;

  final String paymentMode; // "Cash" or "GCash"
  final String cashierUid;

  final double subtotal;
  final double tax;
  final double grandTotal;

  final double amountReceived; // for cash; for gcash = grandTotal
  final double change;

  final List<ReceiptLine> items;

  const ReceiptData({
    required this.invoiceId,
    required this.storeName,
    required this.dateTime,
    required this.paymentMode,
    required this.cashierUid,
    required this.subtotal,
    required this.tax,
    required this.grandTotal,
    required this.amountReceived,
    required this.change,
    required this.items,
  });
}

class ReceiptScreen extends StatelessWidget {
  final ReceiptData data;

  const ReceiptScreen({super.key, required this.data});

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
      'Dec'
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

  String _shareText() {
    final b = StringBuffer();
    b.writeln(data.storeName);
    b.writeln('Invoice #${data.invoiceId}');
    b.writeln(_formatDateTime(data.dateTime));
    b.writeln('Payment: ${data.paymentMode}');
    b.writeln('Cashier: ${data.cashierUid}');
    b.writeln('---');
    for (final it in data.items) {
      b.writeln('${it.name} x${it.qty}  ${_money(it.total)}');
    }
    b.writeln('---');
    b.writeln('Subtotal: ${_money(data.subtotal)}');
    b.writeln('Tax: ${_money(data.tax)}');
    b.writeln('Grand Total: ${_money(data.grandTotal)}');
    if (data.paymentMode.toLowerCase() == 'cash') {
      b.writeln('Received: ${_money(data.amountReceived)}');
      b.writeln('Change: ${_money(data.change)}');
    }
    b.writeln('Thank you! Visit again!');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
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
                // Top bar
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
                    const SizedBox(width: 48), // balance back button
                  ],
                ),
                const SizedBox(height: 8),

                // Check icon
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
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

                // Receipt Card
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Invoice #${data.invoiceId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateTime(data.dateTime),
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1),

                        const SizedBox(height: 10),
                        // Payment summary row like your reference header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _headerCell('P Mode'),
                            _headerCell('I#'),
                            _headerCell('U#'),
                            _headerCell('Amount'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _valueCell(data.paymentMode),
                            _valueCell('${data.items.length}'),
                            _valueCell(data.cashierUid.substring(
                                0, data.cashierUid.length.clamp(0, 6))),
                            _valueCell(_money(data.grandTotal)),
                          ],
                        ),

                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        // Items table header
                        Row(
                          children: const [
                            Expanded(
                                flex: 4,
                                child: Text('Name',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12))),
                            Expanded(
                                flex: 2,
                                child: Text('Price',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12))),
                            Expanded(
                                flex: 1,
                                child: Text('Qty',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12))),
                            Expanded(
                                flex: 2,
                                child: Text('Total',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12))),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Expanded(
                          child: ListView.separated(
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
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      _money(it.price),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${it.qty}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      _money(it.total),
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        const Divider(height: 18),

                        _kv('Sub total', _money(data.subtotal)),
                        _kv('Tax @ 12%', _money(data.tax)),

                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
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
                        const Text(
                          'Thank you! Visit again!',
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Buttons
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
                      // TODO: integrate printing (pdf + printing plugin) if needed
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
                    onPressed: () async {
                      // Share without extra packages: copy text to clipboard
                      await Clipboard.setData(
                          ClipboardData(text: _shareText()));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Receipt copied to clipboard.')),
                      );
                    },
                    child: const Text('SHARE'),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: style),
        Text(v, style: style),
      ],
    );
  }

  static Widget _headerCell(String t) {
    return Expanded(
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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
