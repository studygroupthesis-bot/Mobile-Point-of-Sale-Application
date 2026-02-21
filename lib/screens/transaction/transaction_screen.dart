import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CartItem {
  final String itemId;
  final String name;
  final String? barcode;
  final double price;
  int qty;

  CartItem({
    required this.itemId,
    required this.name,
    required this.price,
    this.barcode,
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
  final _searchController = TextEditingController();
  final List<CartItem> _cart = [];

  bool _loadingAdd = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------
  Future<String> _requireStoreId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Not logged in.");

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final storeId = snap.data()?['storeId'] as String?;
    if (storeId == null || storeId.isEmpty) {
      throw Exception("Missing storeId in users/${user.uid}.");
    }
    return storeId;
  }

  double get subtotal => _cart.fold(0, (t, i) => t + i.total);
  double get vat12 => subtotal * 0.12;
  double get grandTotal => subtotal + vat12;

  void _addOrMergeCartItem({
    required String itemId,
    required String name,
    required double price,
    required int qty,
    String? barcode,
  }) {
    final idx = _cart.indexWhere((e) => e.itemId == itemId);
    setState(() {
      if (idx >= 0) {
        _cart[idx].qty += qty;
      } else {
        _cart.add(CartItem(
          itemId: itemId,
          name: name,
          price: price,
          qty: qty,
          barcode: barcode,
        ));
      }
    });
  }

  Future<int?> _askQuantity({required String itemName}) async {
    final controller = TextEditingController(text: "1");

    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Quantity"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Add quantity for:\n$itemName"),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Quantity",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final q = int.tryParse(controller.text.trim());
              if (q == null || q <= 0) return;
              Navigator.pop(ctx, q);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );

    controller.dispose();
    return qty;
  }

  // ---------- Firestore item lookup ----------
  Future<void> _addItemByBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return;

    setState(() => _loadingAdd = true);
    try {
      final storeId = await _requireStoreId();

      final q = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('items')
          .where('barcode', isEqualTo: barcode.trim())
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No item found for barcode: $barcode')),
        );
        return;
      }

      final doc = q.docs.first;
      final data = doc.data();

      final itemName = (data['name'] ?? '').toString();
      final price = (data['price'] as num?)?.toDouble() ?? 0.0;
      final itemBarcode = (data['barcode'] ?? '').toString();

      final qty = await _askQuantity(itemName: itemName);
      if (qty == null) return;

      _addOrMergeCartItem(
        itemId: doc.id,
        name: itemName,
        price: price,
        qty: qty,
        barcode: itemBarcode,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding item: $e")),
      );
    } finally {
      if (mounted) setState(() => _loadingAdd = false);
    }
  }

  Future<void> _addItemByNameSearch(String nameQuery) async {
    final query = nameQuery.trim();
    if (query.isEmpty) return;

    setState(() => _loadingAdd = true);
    try {
      final storeId = await _requireStoreId();

      // Simple "starts with" search using nameLower.
      // If you don't have nameLower yet, see NOTE below.
      final lower = query.toLowerCase();

      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('items')
          .where('nameLower', isGreaterThanOrEqualTo: lower)
          .where('nameLower', isLessThan: '${lower}')
          .limit(10)
          .get();

      if (snap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No items found for: $query')),
        );
        return;
      }

      // Let user pick from results
      final pickedDoc = await showModalBottomSheet<
          QueryDocumentSnapshot<Map<String, dynamic>>>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => ListView(
          children: [
            const ListTile(
              title: Text("Select item to add"),
            ),
            ...snap.docs.map((doc) {
              final d = doc.data();
              final n = (d['name'] ?? '').toString();
              final p = (d['price'] as num?)?.toDouble() ?? 0.0;
              return ListTile(
                title: Text(n),
                subtitle: Text('₱ ${p.toStringAsFixed(2)}'),
                onTap: () => Navigator.pop(ctx, doc),
              );
            }),
          ],
        ),
      );

      if (pickedDoc == null) return;

      final d = pickedDoc.data();
      final itemName = (d['name'] ?? '').toString();
      final price = (d['price'] as num?)?.toDouble() ?? 0.0;
      final itemBarcode = (d['barcode'] ?? '').toString();

      final qty = await _askQuantity(itemName: itemName);
      if (qty == null) return;

      _addOrMergeCartItem(
        itemId: pickedDoc.id,
        name: itemName,
        price: price,
        qty: qty,
        barcode: itemBarcode,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Search error: $e")),
      );
    } finally {
      if (mounted) setState(() => _loadingAdd = false);
    }
  }

  // ---------- UI actions ----------
  Future<void> _openBarcodeInputDialog() async {
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Scan / Enter Barcode"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Barcode",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Add"),
          ),
        ],
      ),
    );

    controller.dispose();

    if (code == null || code.trim().isEmpty) return;
    await _addItemByBarcode(code);
  }

  // ---------- Build ----------
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    _StoreLogoCircle(size: 36),
                    SizedBox(width: 10),
                    Expanded(child: _StoreNameOrAppTitle()),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Barcode Scanner',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _openBarcodeInputDialog, // ✅ tap to scan/enter barcode
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          hintText: 'Search item name...',
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
                      onPressed: _loadingAdd
                          ? null
                          : () => _addItemByNameSearch(_searchController.text),
                      child: _loadingAdd
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Add Item'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Transaction',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  _cart.isEmpty
                      ? 'Scan/Add Item to transact…'
                      : 'Items in your transaction:',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _cart.isEmpty
                      ? const Center(
                          child: Text(
                            'No items scanned yet',
                            style:
                                TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: _cart.length,
                          itemBuilder: (context, index) {
                            final item = _cart[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 4,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.name}  x${item.qty}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text('₱ ${item.total.toStringAsFixed(2)}'),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                if (_cart.isNotEmpty) ...[
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
                      const Text('Grand Total',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
                    onPressed: _cart.isEmpty
                        ? null
                        : () {
                            // TODO: Save transaction to Firestore (next step)
                          },
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

/// ----- Keep your existing Store widgets (unchanged) -----

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
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}

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

            return Text(display,
                style: _style, overflow: TextOverflow.ellipsis);
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
