import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'receipt_screen.dart';

class StorePaymentConfig {
  final String storeName;
  final bool gcashEnabled;
  final String gcashQrUrl;

  const StorePaymentConfig({
    required this.storeName,
    required this.gcashEnabled,
    required this.gcashQrUrl,
  });

  bool get gcashUsable => gcashEnabled && gcashQrUrl.trim().isNotEmpty;
}

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

  final MobileScannerController _scannerController = MobileScannerController();

  bool _loadingAdd = false;
  bool _loadingSuggest = false;
  bool _processingCheckout = false;
  bool _scannerBusy = false;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _suggestions = [];
  String _lastQuery = '';

  String? _lastScannedCode;
  DateTime? _lastScannedAt;

  @override
  void dispose() {
    _searchController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  String _makeInvoiceNo(String docId) {
    final clean = docId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (clean.isEmpty) return 'D0000000';
    final tail = clean.length >= 7 ? clean.substring(clean.length - 7) : clean;
    return 'D$tail';
  }

  int _safeToInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Future<String> _requireStoreId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in.');

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final storeId = snap.data()?['storeId'] as String?;
    if (storeId == null || storeId.isEmpty) {
      throw Exception('Missing storeId in users/${user.uid}.');
    }
    return storeId;
  }

  double get subtotal => _cart.fold(0, (t, i) => t + i.total);
  double get vat12 => subtotal * 0.12;
  double get grandTotal => subtotal + vat12;

  void _resetSearchUi() {
    _searchController.clear();
    setState(() {
      _suggestions = [];
      _lastQuery = '';
    });
  }

  bool _isRapidDuplicate(String code) {
    final now = DateTime.now();

    if (_lastScannedCode == code &&
        _lastScannedAt != null &&
        now.difference(_lastScannedAt!) < const Duration(seconds: 2)) {
      return true;
    }

    _lastScannedCode = code;
    _lastScannedAt = now;
    return false;
  }

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
        _cart.add(
          CartItem(
            itemId: itemId,
            name: name,
            price: price,
            qty: qty,
            barcode: barcode,
          ),
        );
      }
    });
  }

  Future<int?> _askQuantity({required String itemName}) async {
    final controller = TextEditingController(text: '1');

    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quantity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add quantity for:\n$itemName'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final q = int.tryParse(controller.text.trim());
              if (q == null || q <= 0) return;
              Navigator.pop(ctx, q);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    controller.dispose();
    return qty;
  }

  Future<int?> _askScannedItemQuantity({
    required String itemName,
    required double price,
    String? barcode,
  }) async {
    final controller = TextEditingController(text: '1');

    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scanned Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              itemName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('Price: ₱ ${price.toStringAsFixed(2)}'),
            if (barcode != null && barcode.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Barcode: $barcode',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final q = int.tryParse(controller.text.trim());
              if (q == null || q <= 0) return;
              Navigator.pop(ctx, q);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    controller.dispose();
    return qty;
  }

  Future<void> _removeCartItem(int index) async {
    final item = _cart[index];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text('Remove "${item.name}" from the transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _cart.removeAt(index);
    });
  }

  Future<void> _fetchSuggestions(String input) async {
    final q = input.trim().toLowerCase();

    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _loadingSuggest = false;
        _lastQuery = '';
      });
      return;
    }

    if (q == _lastQuery) return;
    _lastQuery = q;

    setState(() => _loadingSuggest = true);

    try {
      final storeId = await _requireStoreId();

      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('items')
          .orderBy('nameLower')
          .startAt([q])
          .endAt(['$q\uf8ff'])
          .limit(8)
          .get();

      if (!mounted) return;
      setState(() {
        _suggestions = snap.docs;
        _loadingSuggest = false;
      });
    } catch (e) {
      debugPrint('SUGGEST ERROR: $e');
      if (!mounted) return;
      setState(() => _loadingSuggest = false);
    }
  }

  Future<void> _addFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final d = doc.data();
    final name = (d['name'] ?? '').toString();
    final price = (d['price'] as num?)?.toDouble() ?? 0.0;
    final barcode = (d['barcode'] ?? '').toString();

    final qty = await _askQuantity(itemName: name);
    if (qty == null) return;

    _addOrMergeCartItem(
      itemId: doc.id,
      name: name,
      price: price,
      qty: qty,
      barcode: barcode,
    );

    _resetSearchUi();
  }

  Future<void> _openBarcodeInputDialog() async {
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan / Enter Barcode'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Barcode',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (code == null || code.trim().isEmpty) return;
    await _addItemByBarcode(code.trim(), showScannedDialog: false);
  }

  Future<void> _handleEmbeddedScan(BarcodeCapture capture) async {
    if (_scannerBusy || _loadingAdd || _processingCheckout) return;

    final codes = capture.barcodes;
    if (codes.isEmpty) return;

    final value = codes.first.rawValue?.trim();
    if (value == null || value.isEmpty) return;

    if (_isRapidDuplicate(value)) return;

    _scannerBusy = true;
    await _scannerController.stop();

    try {
      await _addItemByBarcode(value, showScannedDialog: true);
    } finally {
      if (mounted) {
        _scannerBusy = false;
        await _scannerController.start();
      }
    }
  }

  Future<void> _addItemByBarcode(
    String barcode, {
    required bool showScannedDialog,
  }) async {
    setState(() => _loadingAdd = true);

    try {
      final storeId = await _requireStoreId();

      final q = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('items')
          .where('barcode', isEqualTo: barcode)
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
      final d = doc.data();
      final name = (d['name'] ?? '').toString();
      final price = (d['price'] as num?)?.toDouble() ?? 0.0;
      final savedBarcode = (d['barcode'] ?? '').toString();

      final qty = showScannedDialog
          ? await _askScannedItemQuantity(
              itemName: name,
              price: price,
              barcode: savedBarcode,
            )
          : await _askQuantity(itemName: name);

      if (qty == null) return;

      _addOrMergeCartItem(
        itemId: doc.id,
        name: name,
        price: price,
        qty: qty,
        barcode: savedBarcode,
      );

      _resetSearchUi();
    } catch (e) {
      debugPrint('BARCODE ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding item: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingAdd = false);
    }
  }

  Future<StorePaymentConfig> _fetchStorePaymentConfigSafe() async {
    try {
      final storeId = await _requireStoreId();
      final storeDoc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .get();

      final data = storeDoc.data() ?? {};

      final storeName =
          (data['business_name'] ?? data['name'] ?? 'Business Sale').toString();

      final payment = (data['payment'] as Map<String, dynamic>?) ?? {};
      final gcashEnabled = (data['accept_gcash'] as bool?) ??
          (payment['gcashEnabled'] as bool?) ??
          false;
      final gcashQrUrl =
          (data['gcashQrUrl'] ?? payment['gcashQrUrl'] ?? '').toString();

      return StorePaymentConfig(
        storeName: storeName,
        gcashEnabled: gcashEnabled,
        gcashQrUrl: gcashQrUrl,
      );
    } catch (e) {
      debugPrint('PAYMENT CONFIG ERROR: $e');
      return const StorePaymentConfig(
        storeName: 'Business Sale',
        gcashEnabled: false,
        gcashQrUrl: '',
      );
    }
  }

  Future<void> _startCheckout() async {
    if (_cart.isEmpty || _processingCheckout) return;

    setState(() => _processingCheckout = true);

    final config = await _fetchStorePaymentConfigSafe();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select Payment Method',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.payments),
                  title: const Text('Cash'),
                  subtitle: const Text('Confirm amount received'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _cashFlow(config);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.qr_code,
                    color: config.gcashUsable ? null : Colors.black26,
                  ),
                  title: Text(
                    'GCash',
                    style: TextStyle(
                      color: config.gcashUsable ? null : Colors.black26,
                    ),
                  ),
                  subtitle: Text(
                    config.gcashUsable
                        ? 'Show store QR code'
                        : 'Unavailable (disabled or QR not set)',
                    style: TextStyle(
                      color: config.gcashUsable ? null : Colors.black26,
                    ),
                  ),
                  onTap: config.gcashUsable
                      ? () async {
                          Navigator.pop(ctx);
                          await _gcashFlow(config);
                        }
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );

    if (mounted) {
      setState(() => _processingCheckout = false);
    }
  }

  Future<void> _cashFlow(StorePaymentConfig config) async {
    final controller = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cash Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Grand Total: ₱ ${grandTotal.toStringAsFixed(2)}'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount received',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      controller.dispose();
      return;
    }

    final received = double.tryParse(controller.text.trim());
    controller.dispose();

    if (received == null || received < grandTotal) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Amount received must be greater than or equal to total.'),
        ),
      );
      return;
    }

    await _completeSale(
      config: config,
      paymentMode: 'Cash',
      amountReceived: received,
    );
  }

  Future<void> _gcashFlow(StorePaymentConfig config) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GCash Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Grand Total: ₱ ${grandTotal.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  config.gcashQrUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return const Center(child: Text('QR failed to load'));
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Let the customer scan the QR code, then confirm payment.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _completeSale(
      config: config,
      paymentMode: 'GCash',
      amountReceived: grandTotal,
    );
  }

  Future<void> _completeSale({
    required StorePaymentConfig config,
    required String paymentMode,
    required double amountReceived,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in.')),
      );
      return;
    }

    try {
      final storeId = await _requireStoreId();

      final change = paymentMode.toLowerCase() == 'cash'
          ? (amountReceived - grandTotal)
          : 0.0;

      final firestore = FirebaseFirestore.instance;
      final txRef = firestore
          .collection('stores')
          .doc(storeId)
          .collection('transactions')
          .doc();

      final now = DateTime.now();
      final invoiceNo = _makeInvoiceNo(txRef.id);

      await firestore.runTransaction((transaction) async {
        final itemRefs = <String, DocumentReference<Map<String, dynamic>>>{};
        final currentStocks = <String, int>{};

        for (final cartItem in _cart) {
          final itemRef = firestore
              .collection('stores')
              .doc(storeId)
              .collection('items')
              .doc(cartItem.itemId);

          final itemSnap = await transaction.get(itemRef);

          if (!itemSnap.exists) {
            throw Exception('Item "${cartItem.name}" no longer exists.');
          }

          final data = itemSnap.data() ?? {};
          final currentStock = _safeToInt(data['stockQty']);

          if (currentStock < cartItem.qty) {
            throw Exception(
              'Not enough stock for "${cartItem.name}". '
              'Available: $currentStock, Requested: ${cartItem.qty}',
            );
          }

          itemRefs[cartItem.itemId] = itemRef;
          currentStocks[cartItem.itemId] = currentStock;
        }

        transaction.set(txRef, {
          'createdAt': FieldValue.serverTimestamp(),
          'createdAtLocal': now.toIso8601String(),
          'invoiceId': txRef.id,
          'invoiceNo': invoiceNo,
          'invoiceNoLower': invoiceNo.toLowerCase(),
          'storeId': storeId,
          'storeName': config.storeName,
          'paymentMethod': paymentMode,
          'paymentMode': paymentMode,
          'total': grandTotal,
          'status': 'Success',
          'cashierUid': user.uid,
          'subtotal': subtotal,
          'tax': vat12,
          'grandTotal': grandTotal,
          'amountReceived': amountReceived,
          'change': change,
          'items': _cart.map((i) {
            return {
              'itemId': i.itemId,
              'name': i.name,
              'barcode': i.barcode,
              'price': i.price,
              'qty': i.qty,
              'total': i.total,
            };
          }).toList(),
        });

        for (final cartItem in _cart) {
          final itemRef = itemRefs[cartItem.itemId]!;
          final currentStock = currentStocks[cartItem.itemId]!;
          final newStock = currentStock - cartItem.qty;

          transaction.update(itemRef, {
            'stockQty': newStock,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final stockLogRef = firestore
              .collection('stores')
              .doc(storeId)
              .collection('stock_logs')
              .doc();

          transaction.set(stockLogRef, {
            'createdAt': FieldValue.serverTimestamp(),
            'itemId': cartItem.itemId,
            'itemName': cartItem.name,
            'barcode': cartItem.barcode,
            'type': 'stock_out',
            'reason': 'sale',
            'qty': cartItem.qty,
            'beforeQty': currentStock,
            'afterQty': newStock,
            'referenceId': txRef.id,
            'referenceType': 'transaction',
            'invoiceNo': invoiceNo,
            'cashierUid': user.uid,
          });
        }
      });

      debugPrint('RUN TRANSACTION SUCCESS');

      final receipt = ReceiptData(
        invoiceId: txRef.id,
        invoiceNo: invoiceNo,
        storeName: config.storeName,
        dateTime: now,
        paymentMode: paymentMode,
        cashierUid: user.uid,
        subtotal: subtotal,
        tax: vat12,
        grandTotal: grandTotal,
        amountReceived: amountReceived,
        change: change,
        items: _cart
            .map((c) => ReceiptLine(name: c.name, price: c.price, qty: c.qty))
            .toList(),
      );

      if (!mounted) return;

      setState(() {
        _cart.clear();
        _suggestions = [];
        _lastQuery = '';
        _searchController.clear();
      });

      await Future.delayed(const Duration(milliseconds: 120));

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(data: receipt),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: $e')),
      );
    }
  }

  Widget _buildScannerCard() {
    return GestureDetector(
      onTap: () async {
        if (_loadingAdd || _processingCheckout || _scannerBusy) return;
        await _scannerController.start();
      },
      child: Container(
        height: 130,
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _handleEmbeddedScan,
              ),
              Center(
                child: Container(
                  width: 220,
                  height: 70,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_loadingAdd || _scannerBusy)
                Container(
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _loadingAdd
                        ? 'Looking up scanned item...'
                        : _scannerBusy
                            ? 'Processing scan...'
                            : 'Align barcode inside the frame',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Barcode Scanner',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _buildScannerCard(),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loadingAdd ? null : _openBarcodeInputDialog,
                    child: const Text('Enter barcode manually'),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _fetchSuggestions,
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
                      onPressed: null,
                      child: const Text('Add Item'),
                    ),
                  ],
                ),
                if (_loadingSuggest)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: _suggestions.map((doc) {
                        final d = doc.data();
                        final name = (d['name'] ?? '').toString();
                        final price = (d['price'] as num?)?.toDouble() ?? 0.0;
                        final barcode = (d['barcode'] ?? '').toString();

                        return ListTile(
                          dense: true,
                          title: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '₱ ${price.toStringAsFixed(2)}'
                            '${barcode.isNotEmpty ? ' • $barcode' : ''}',
                          ),
                          onTap: () => _addFromDoc(doc),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Transaction',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
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
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
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
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.name}  x${item.qty}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text('₱ ${item.total.toStringAsFixed(2)}'),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () => _removeCartItem(index),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
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
                      const Text(
                        'Grand Total',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
                    onPressed:
                        (_cart.isEmpty || _loadingAdd || _processingCheckout)
                            ? null
                            : _startCheckout,
                    child: _processingCheckout
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
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
