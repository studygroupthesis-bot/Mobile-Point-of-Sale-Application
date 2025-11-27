import 'package:flutter/material.dart';

class TransactionItem {
  final String name;
  final double price;
  int qty;

  TransactionItem({
    required this.name,
    required this.price,
    this.qty = 1,
  });

  double get total => price * qty;
}

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final List<TransactionItem> _items = [];

  // TEMP: Manual add for now (later: barcode)
  void _addSampleItem() {
    setState(() {
      _items.add(TransactionItem(
        name: "Century Tuna",
        price: 50.0,
        qty: 1,
      ));
      _items.add(TransactionItem(
        name: "Century Tuna Spicy",
        price: 50.0,
        qty: 1,
      ));
    });
  }

  // Placeholder for barcode scanning integration
  Future<void> scanBarcode() async {
    // TODO: Integrate real barcode scanner later
    // For now just add sample item
    _addSampleItem();
  }

  double get subtotal {
    return _items.fold(0, (sum, item) => sum + item.total);
  }

  double get vat12 {
    return subtotal * 0.12;
  }

  double get grandTotal {
    return subtotal + vat12;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7CBD0), // pink background
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //
                // HEADER (DALI LOGO)
                //
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.pinkAccent,
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'DALI',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                //
                // BARCODE LABEL
                //
                const Text(
                  'Barcode Scanner',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),

                //
                // BARCODE DISPLAY (STATIC)
                //
                GestureDetector(
                  onTap: scanBarcode, // tap to simulate scan
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        15,
                        (index) => Container(
                          width: index.isEven ? 4 : 2,
                          height: 60,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          color: index.isEven ? Colors.black87 : Colors.black26,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                //
                // SEARCH + ADD BUTTON
                //
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          hintText: 'Search...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A88B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: _addSampleItem,
                      child: const Text('Add Item'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                //
                // TRANSACTION TITLE
                //
                const Text(
                  'Transaction',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _items.isEmpty
                      ? 'Scan/Add Item to transact…'
                      : 'Items in your transaction:',
                  style: const TextStyle(fontSize: 12),
                ),

                const SizedBox(height: 8),

                //
                // TRANSACTION LIST OR EMPTY PLACEHOLDER
                //
                Expanded(
                  child: _items.isEmpty
                      ? const Center(
                          child: Text(
                            'No items scanned yet',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${item.name}  x${item.qty}'),
                                  Text('₱ ${item.total.toStringAsFixed(2)}'),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                //
                // TOTALS (only if items exist)
                //
                if (_items.isNotEmpty) ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sub Total'),
                      Text('₱ ${subtotal.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tax @ 12%'),
                      Text('₱ ${vat12.toStringAsFixed(2)}'),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Grand Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₱ ${grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                //
                // TRANSACT BUTTON
                //
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
                    onPressed: _items.isEmpty ? null : () {},
                    child: const Text(
                      'TRANSACT',
                      style: TextStyle(
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
