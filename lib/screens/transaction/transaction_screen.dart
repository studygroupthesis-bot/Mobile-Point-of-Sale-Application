import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> scanBarcode() async {
    _addSampleItem();
  }

  double get subtotal => _items.fold(0, (total, item) => total + item.total);
  double get vat12 => subtotal * 0.12;
  double get grandTotal => subtotal + vat12;

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
                // HEADER (STORE LOGO + STORE NAME)
                //
                const Row(
                  children: [
                    _StoreLogoCircle(size: 36),
                    SizedBox(width: 10),
                    Expanded(child: _StoreNameOrAppTitle()),
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
                          color: Colors.black.withValues(alpha: 0.05),
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
                                vertical: 4,
                                horizontal: 4,
                              ),
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

/// Shows store logo from Firestore:
/// users/{uid}.storeId -> stores/{storeId}.logo_url
/// Falls back to the "!" badge if no logo exists.
class _StoreLogoCircle extends StatelessWidget {
  final double size;
  const _StoreLogoCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _fallback();

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, userSnap) {
        final storeId = userSnap.data?.data()?['storeId'] as String?;
        if (storeId == null || storeId.isEmpty) return _fallback();

        final storeRef =
            FirebaseFirestore.instance.collection('stores').doc(storeId);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: storeRef.snapshots(),
          builder: (context, storeSnap) {
            final logoUrl = storeSnap.data?.data()?['logo_url'] as String?;

            return Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromARGB(255, 94, 223, 122),
              ),
              child: ClipOval(
                child: (logoUrl != null && logoUrl.isNotEmpty)
                    ? Image.network(
                        logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackIcon(),
                      )
                    : _fallbackIcon(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color.fromARGB(255, 94, 223, 122),
      ),
      child: _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() {
    return const Center(
      child: Text(
        '!',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Shows store business name from Firestore:
/// users/{uid}.storeId -> stores/{storeId}.business_name
/// Falls back to "POP2Pay" if no store name exists.
class _StoreNameOrAppTitle extends StatelessWidget {
  const _StoreNameOrAppTitle();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Text('POP2Pay', style: _style);

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, userSnap) {
        final storeId = userSnap.data?.data()?['storeId'] as String?;
        if (storeId == null || storeId.isEmpty) {
          return const Text('POP2Pay', style: _style);
        }

        final storeRef =
            FirebaseFirestore.instance.collection('stores').doc(storeId);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: storeRef.snapshots(),
          builder: (context, storeSnap) {
            final name = storeSnap.data?.data()?['business_name'] as String?;
            final display = (name != null && name.trim().isNotEmpty)
                ? name.trim()
                : 'POP2Pay';

            return Text(
              display,
              style: _style,
              overflow: TextOverflow.ellipsis,
            );
          },
        );
      },
    );
  }

  static const TextStyle _style = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 18,
  );
}
