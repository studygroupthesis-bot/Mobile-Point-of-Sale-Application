import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'receipt_screen.dart';

class CartItem {
  final String itemId;
  final String name;
  final double price;
  final String barcode;
  final int qty;
  final String soldBy;
  final int? availableStock;
  final String? imageUrl;
  final String? representationType;
  final int? colorValue;

  const CartItem({
    required this.itemId,
    required this.name,
    required this.price,
    required this.barcode,
    required this.qty,
    this.soldBy = 'each',
    this.availableStock,
    this.imageUrl,
    this.representationType,
    this.colorValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'name': name,
      'price': price,
      'qty': qty,
      'barcode': barcode,
      'soldBy': soldBy,
      'availableStock': availableStock,
      'imageUrl': imageUrl,
      'representationType': representationType,
      'colorValue': colorValue,
    };
  }
}

class TransactionScreen extends StatefulWidget {
  final String? storeId;
  final String? storeName;
  final bool isActive;
  final List<CartItem> initialCart;

  const TransactionScreen({
    super.key,
    this.storeId,
    this.storeName,
    this.isActive = true,
    this.initialCart = const [],
  });

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualBarcodeController =
      TextEditingController();

  late final MobileScannerController _scannerController;

  bool _loading = true;
  bool _addingByBarcode = false;
  bool _searchingItems = false;
  bool _savingTransaction = false;
  bool _scannerEnabled = true;

  String? _storeId;
  String? _storeName;
  String? _lastScannedBarcode;
  DateTime? _lastScannedAt;

  bool _acceptCashPayment = true;
  bool _acceptGcashPayment = false;
  String _gcashQrImageUrl = '';
  String _gcashName = '';
  String _gcashNumber = '';

  final List<Map<String, dynamic>> _cartItems = [];
  List<DocumentSnapshot<Map<String, dynamic>>> _liveSuggestions = [];

  static const Color _navy = Color(0xFF083B7A);
  static const Color _teal = Color(0xFF2F9E9C);
  static const Color _softTeal = Color(0xFFDDF1EF);
  static const Color _pageBg = Color(0xFFEAF6F4);

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      autoStart: widget.isActive,
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
    );
    _seedInitialCart();
    _loadStoreContext();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _manualBarcodeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _seedInitialCart() {
    for (final item in widget.initialCart) {
      final existingIndex = _cartItems.indexWhere(
        (cartItem) => cartItem['itemId'] == item.itemId,
      );

      if (existingIndex >= 0) {
        final currentQty = _toInt(_cartItems[existingIndex]['qty']);
        _cartItems[existingIndex]['qty'] = currentQty + item.qty;
      } else {
        _cartItems.add(item.toMap());
      }
    }
  }

  Future<void> _loadStoreContext() async {
    try {
      String? resolvedStoreId = widget.storeId?.trim();
      String? resolvedStoreName = widget.storeName?.trim();

      if (resolvedStoreId == null || resolvedStoreId.isEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('Not logged in. Please login again.');
        }

        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final userData = userSnap.data() ?? <String, dynamic>{};
        resolvedStoreId = (userData['storeId'] as String?)?.trim();

        if (resolvedStoreId == null || resolvedStoreId.isEmpty) {
          throw Exception('No storeId found for this user.');
        }
      }

      final storeSnap = await FirebaseFirestore.instance
          .collection('stores')
          .doc(resolvedStoreId)
          .get();

      final storeData = storeSnap.data() ?? <String, dynamic>{};

      resolvedStoreName =
          (storeData['business_name'] as String?)?.trim().isNotEmpty == true
              ? (storeData['business_name'] as String).trim()
              : ((storeData['storeName'] as String?)?.trim() ??
                  resolvedStoreName);

      if (!mounted) return;

      setState(() {
        _storeId = resolvedStoreId;
        _storeName = resolvedStoreName;
        _acceptCashPayment = (storeData['accept_cash'] as bool?) ?? true;
        _acceptGcashPayment = (storeData['accept_gcash'] as bool?) ?? false;
        _gcashQrImageUrl = (storeData['gcashQrImageUrl'] as String?) ??
            (storeData['gcashQrUrl'] as String?) ??
            '';
        _gcashName = (storeData['gcashName'] as String?) ?? '';
        _gcashNumber = (storeData['gcashNumber'] as String?) ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load transaction screen: $e')),
      );
    }
  }

  String _normalizeBarcodeValue(dynamic value) {
    if (value == null) return '';
    var text = value.toString().trim().replaceAll(RegExp(r'\s+'), '');
    if (text.endsWith('.0')) {
      text = text.substring(0, text.length - 2);
    }
    return text;
  }

  String _firstNonEmptyString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim()) ?? 0;
  }

  String _extractItemName(Map<String, dynamic> data) {
    final name = _firstNonEmptyString(data, [
      'name',
      'itemName',
      'productName',
      'item_name',
      'title',
      'label',
    ]);
    return name.isEmpty ? 'Unnamed Item' : name;
  }

  String _extractItemCategory(Map<String, dynamic> data) {
    return _firstNonEmptyString(data, [
      'category',
      'itemCategory',
      'productCategory',
      'type',
    ]);
  }

  String _extractItemCode(Map<String, dynamic> data) {
    return _firstNonEmptyString(data, [
      'itemCode',
      'sku',
      'code',
    ]);
  }

  String _extractItemBarcode(Map<String, dynamic> data) {
    final raw = _firstNonEmptyString(data, [
      'barcode',
      'barcodeValue',
      'barcodeNumber',
      'sku',
      'itemCode',
      'code',
    ]);
    return _normalizeBarcodeValue(raw);
  }

  String _extractSoldBy(Map<String, dynamic> data) {
    final soldBy = _firstNonEmptyString(data, [
      'soldBy',
      'unit',
      'unitType',
      'measure',
    ]);
    return soldBy.isEmpty ? 'each' : soldBy;
  }

  double _extractPrice(Map<String, dynamic> data) {
    return _toDouble(
      data['price'] ??
          data['sellingPrice'] ??
          data['unitPrice'] ??
          data['amount'] ??
          0,
    );
  }

  int _extractStock(Map<String, dynamic> data) {
    return _toInt(
      data['stockQty'] ??
          data['stock'] ??
          data['quantity'] ??
          data['stocks'] ??
          data['currentStock'] ??
          0,
    );
  }

  bool _matchesSearch(Map<String, dynamic> data, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return false;

    final fields = [
      _extractItemName(data).toLowerCase(),
      _firstNonEmptyString(data, ['nameLower']).toLowerCase(),
      _extractItemCategory(data).toLowerCase(),
      _extractItemBarcode(data).toLowerCase(),
      _extractItemCode(data).toLowerCase(),
      _firstNonEmptyString(data, ['brand']).toLowerCase(),
      _firstNonEmptyString(data, ['description']).toLowerCase(),
    ];

    return fields.any((field) => field.isNotEmpty && field.contains(query));
  }

  int _searchRank(Map<String, dynamic> data, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();

    final name = _extractItemName(data).toLowerCase();
    final barcode = _extractItemBarcode(data).toLowerCase();
    final code = _extractItemCode(data).toLowerCase();
    final category = _extractItemCategory(data).toLowerCase();

    if (name == query || barcode == query || code == query) return 0;
    if (name.startsWith(query) || code.startsWith(query)) return 1;
    if (name.contains(query)) return 2;
    if (category.contains(query)) return 3;
    if (barcode.contains(query) || code.contains(query)) return 4;
    return 5;
  }

  double get _cartTotal {
    double total = 0;
    for (final item in _cartItems) {
      final price = _toDouble(item['price']);
      final qty = _toInt(item['qty']);
      total += price * qty;
    }
    return total;
  }

  int get _cartItemCount {
    int total = 0;
    for (final item in _cartItems) {
      total += _toInt(item['qty']);
    }
    return total;
  }

  String _buildPublicReceiptUrl({
    required String storeId,
    required String transactionId,
  }) {
    return 'https://fir-pos-system.web.app/#/public-receipt'
        '?storeId=$storeId&transactionId=$transactionId';
  }

  Future<void> _savePublicReceipt({
    required String storeId,
    required String transactionId,
    required String invoiceNo,
    required String cashierUid,
    required String paymentMode,
    required double subtotal,
    required double taxableSales,
    required bool taxEnabled,
    required String taxName,
    required double taxRate,
    required bool taxInclusive,
    required double tax,
    required double grandTotal,
    required double amountReceived,
    required double change,
    required List<Map<String, dynamic>> items,
    required String storeName,
    required DateTime now,
  }) async {
    await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('public_receipts')
        .doc(transactionId)
        .set({
      'transactionId': transactionId,
      'invoiceId': transactionId,
      'invoiceNo': invoiceNo,
      'storeId': storeId,
      'storeName': storeName,
      'cashierUid': cashierUid,
      'paymentMode': paymentMode,
      'paymentMethod': paymentMode,
      'subtotal': subtotal,
      'taxableSales': taxableSales,
      'taxEnabled': taxEnabled,
      'taxName': taxName,
      'taxRate': taxRate,
      'taxInclusive': taxInclusive,
      'tax': tax,
      'taxAmount': tax,
      'grandTotal': grandTotal,
      'total': grandTotal,
      'amountReceived': amountReceived,
      'amountPaid': amountReceived,
      'change': change,
      'items': items,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtLocal': now.toIso8601String(),
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findItemByBarcode(
    String rawBarcode,
  ) async {
    final storeId = _storeId;
    final normalized = _normalizeBarcodeValue(rawBarcode);

    if (storeId == null || storeId.isEmpty || normalized.isEmpty) {
      return null;
    }

    final collection = FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('items');

    final exactFields = [
      'barcode',
      'barcodeValue',
      'barcodeNumber',
      'sku',
      'itemCode',
      'code',
    ];

    for (final field in exactFields) {
      final snap =
          await collection.where(field, isEqualTo: normalized).limit(1).get();
      if (snap.docs.isNotEmpty) return snap.docs.first;
    }

    final allDocs = await collection.get();
    for (final doc in allDocs.docs) {
      final data = doc.data();
      final candidates = [
        data['barcode'],
        data['barcodeValue'],
        data['barcodeNumber'],
        data['sku'],
        data['itemCode'],
        data['code'],
      ];

      for (final candidate in candidates) {
        if (_normalizeBarcodeValue(candidate) == normalized) {
          return doc;
        }
      }
    }

    return null;
  }

  void _addItemDocumentToCart(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final name = _extractItemName(data);
    final price = _extractPrice(data);
    final barcode = _extractItemBarcode(data);
    final soldBy = _extractSoldBy(data);
    final availableStock = _extractStock(data);

    final existingIndex = _cartItems.indexWhere(
      (item) => item['itemId'] == doc.id,
    );

    setState(() {
      if (existingIndex >= 0) {
        final currentQty = _toInt(_cartItems[existingIndex]['qty']);
        if (availableStock <= 0 || currentQty >= availableStock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Maximum stock reached for $name.')),
          );
          return;
        }

        _cartItems[existingIndex]['qty'] = currentQty + 1;
      } else {
        if (availableStock <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name is out of stock.')),
          );
          return;
        }

        _cartItems.add({
          'itemId': doc.id,
          'name': name,
          'price': price,
          'barcode': barcode,
          'qty': 1,
          'soldBy': soldBy,
          'availableStock': availableStock,
          'imageUrl': data['imageUrl'],
          'representationType': data['representationType'],
          'colorValue': data['colorValue'],
        });
      }
    });
  }

  Future<void> _addItemByBarcode(String rawBarcode) async {
    final normalized = _normalizeBarcodeValue(rawBarcode);

    if (normalized.isEmpty) return;
    if (_addingByBarcode) return;

    setState(() => _addingByBarcode = true);

    try {
      final doc = await _findItemByBarcode(normalized);
      if (!mounted) return;

      if (doc == null || !doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No item found for barcode: $normalized')),
        );
        return;
      }

      _addItemDocumentToCart(doc);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add barcode: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _addingByBarcode = false);
      }
    }
  }

  Future<void> _handleBarcodeDetection(BarcodeCapture capture) async {
    if (!_scannerEnabled || _addingByBarcode) return;

    final code = capture.barcodes
        .map((e) => e.rawValue?.trim() ?? '')
        .firstWhere((e) => e.isNotEmpty, orElse: () => '');

    if (code.isEmpty) return;

    final now = DateTime.now();
    if (_lastScannedBarcode == code &&
        _lastScannedAt != null &&
        now.difference(_lastScannedAt!) < const Duration(seconds: 2)) {
      return;
    }

    _lastScannedBarcode = code;
    _lastScannedAt = now;

    _scannerEnabled = false;
    await _scannerController.stop();
    await _addItemByBarcode(code);

    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _scannerEnabled = true;
    await _scannerController.start();
  }

  Future<void> _showManualBarcodeDialog() async {
    _manualBarcodeController.clear();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Barcode'),
          content: TextField(
            controller: _manualBarcodeController,
            autofocus: true,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              hintText: 'Type or paste barcode',
            ),
            onSubmitted: (_) {
              Navigator.pop(context, _manualBarcodeController.text.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _manualBarcodeController.text.trim());
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result == null || result.trim().isEmpty) return;
    await _addItemByBarcode(result);
  }

  Future<void> _updateLiveSuggestions(String rawQuery) async {
    final storeId = _storeId;
    final query = rawQuery.trim();

    if (storeId == null || storeId.isEmpty) return;

    if (query.isEmpty) {
      if (!mounted) return;
      setState(() => _liveSuggestions = []);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('items')
          .get();

      final results = snap.docs.where((doc) {
        return _matchesSearch(doc.data(), query);
      }).toList()
        ..sort((a, b) {
          final rankA = _searchRank(a.data(), query);
          final rankB = _searchRank(b.data(), query);
          return rankA.compareTo(rankB);
        });

      if (!mounted) return;
      setState(() {
        _liveSuggestions = results.take(6).toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _liveSuggestions = []);
    }
  }

  Future<void> _searchAndPickItem() async {
    final storeId = _storeId;
    final rawQuery = _searchController.text.trim();

    if (storeId == null || storeId.isEmpty) return;

    if (rawQuery.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an item name first.')),
      );
      return;
    }

    setState(() => _searchingItems = true);

    try {
      final collection = FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('items');

      final barcodeMatch = await _findItemByBarcode(rawQuery);
      if (!mounted) return;

      if (barcodeMatch != null && barcodeMatch.exists) {
        _addItemDocumentToCart(barcodeMatch);
        _searchController.clear();
        setState(() => _liveSuggestions = []);
        return;
      }

      final snap = await collection.get();

      final results = snap.docs.where((doc) {
        final data = doc.data();
        return _matchesSearch(data, rawQuery);
      }).toList()
        ..sort((a, b) {
          final rankA = _searchRank(a.data(), rawQuery);
          final rankB = _searchRank(b.data(), rawQuery);
          return rankA.compareTo(rankB);
        });

      if (!mounted) return;

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No items found for "$rawQuery".')),
        );
        return;
      }

      if (results.length == 1) {
        _addItemDocumentToCart(results.first);
        _searchController.clear();
        setState(() => _liveSuggestions = []);
        return;
      }

      final picked =
          await showModalBottomSheet<DocumentSnapshot<Map<String, dynamic>>>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          final maxHeight = MediaQuery.of(context).size.height * 0.65;

          return SafeArea(
            child: SizedBox(
              height: maxHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Item',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final doc = results[index];
                          final data = doc.data();
                          final name = _extractItemName(data);
                          final category = _extractItemCategory(data);
                          final price = _extractPrice(data);
                          final stock = _extractStock(data);

                          return ListTile(
                            title: Text(name),
                            subtitle: Text(
                              '${category.isEmpty ? 'Uncategorized' : category} • Stock: $stock • ₱${price.toStringAsFixed(2)}',
                            ),
                            onTap: () => Navigator.pop(context, doc),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (picked != null) {
        _addItemDocumentToCart(picked);
        _searchController.clear();
        setState(() => _liveSuggestions = []);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to search items: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _searchingItems = false);
      }
    }
  }

  void _increaseQty(int index) {
    final currentQty = _toInt(_cartItems[index]['qty']);
    final rawAvailableStock = _cartItems[index]['availableStock'];
    final int? availableStock =
        rawAvailableStock == null ? null : _toInt(rawAvailableStock);
    final name = _cartItems[index]['name']?.toString() ?? 'Item';

    if (availableStock != null &&
        availableStock > 0 &&
        currentQty >= availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum stock reached for $name.')),
      );
      return;
    }

    setState(() {
      _cartItems[index]['qty'] = currentQty + 1;
    });
  }

  void _decreaseQty(int index) {
    final currentQty = _toInt(_cartItems[index]['qty']);

    setState(() {
      if (currentQty <= 1) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index]['qty'] = currentQty - 1;
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  Future<void> _proceedToTransact() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items scanned yet.')),
      );
      return;
    }

    final storeId = _storeId;
    if (storeId == null || storeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store is not available right now.')),
      );
      return;
    }

    if (!_acceptCashPayment && !_acceptGcashPayment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No payment method is enabled in Store Settings.'),
        ),
      );
      return;
    }

    final paymentResult = await _showPaymentSheet();
    if (paymentResult == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in. Please login again.')),
      );
      return;
    }

    final total = _cartTotal;
    final amountReceived = paymentResult['amountReceived'] as double;
    final paymentMode = paymentResult['paymentMode'] as String;
    final change = paymentResult['change'] as double;

    setState(() => _savingTransaction = true);

    try {
      final db = FirebaseFirestore.instance;
      final txRef =
          db.collection('stores').doc(storeId).collection('transactions').doc();
      final now = DateTime.now();
      final invoiceNo = 'INV-${now.millisecondsSinceEpoch}';
      final resolvedStoreName =
          (_storeName == null || _storeName!.trim().isEmpty)
              ? 'Store'
              : _storeName!.trim();

      final items = _cartItems.map((item) {
        final price = _toDouble(item['price']);
        final qty = _toInt(item['qty']);
        return {
          'itemId': item['itemId'],
          'name': item['name'],
          'price': price,
          'qty': qty,
          'barcode': item['barcode'],
          'soldBy': item['soldBy'] ?? 'each',
          'availableStock': item['availableStock'],
          'imageUrl': item['imageUrl'],
          'representationType': item['representationType'],
          'colorValue': item['colorValue'],
          'lineTotal': price * qty,
          'total': price * qty,
        };
      }).toList();

      final publicReceiptUrl = _buildPublicReceiptUrl(
        storeId: storeId,
        transactionId: txRef.id,
      );

      final batch = db.batch();

      batch.set(txRef, {
        'invoiceId': txRef.id,
        'invoiceNo': invoiceNo,
        'invoiceNoLower': invoiceNo.toLowerCase(),
        'storeId': storeId,
        'storeName': resolvedStoreName,
        'cashierUid': user.uid,
        'status': 'success',
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtLocal': now.toIso8601String(),
        'paymentMode': paymentMode,
        'paymentMethod': paymentMode,
        'subtotal': total,
        'taxableSales': total,
        'taxEnabled': false,
        'taxName': 'VAT',
        'taxRate': 12.0,
        'taxInclusive': true,
        'tax': 0.0,
        'taxAmount': 0.0,
        'grandTotal': total,
        'total': total,
        'amountReceived': amountReceived,
        'amountPaid': amountReceived,
        'change': change,
        'publicReceiptUrl': publicReceiptUrl,
        'items': items,
      });

      for (final item in _cartItems) {
        final itemId = (item['itemId'] ?? '').toString().trim();
        if (itemId.isEmpty) continue;

        final itemRef = db
            .collection('stores')
            .doc(storeId)
            .collection('items')
            .doc(itemId);
        final purchasedQty = _toInt(item['qty']);
        final currentStock = _toInt(item['availableStock']);
        final updatedStock = (currentStock - purchasedQty).clamp(0, 1 << 30);

        batch.update(itemRef, {
          'stockQty': updatedStock,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      await _savePublicReceipt(
        storeId: storeId,
        transactionId: txRef.id,
        invoiceNo: invoiceNo,
        cashierUid: user.uid,
        paymentMode: paymentMode,
        subtotal: total,
        taxableSales: total,
        taxEnabled: false,
        taxName: 'VAT',
        taxRate: 12.0,
        taxInclusive: true,
        tax: 0.0,
        grandTotal: total,
        amountReceived: amountReceived,
        change: change,
        items: items,
        storeName: resolvedStoreName,
        now: now,
      );

      final receipt = ReceiptData(
        invoiceId: txRef.id,
        invoiceNo: invoiceNo,
        storeName: resolvedStoreName,
        dateTime: now,
        paymentMode: paymentMode,
        cashierUid: user.uid,
        subtotal: total,
        taxableSales: total,
        taxEnabled: false,
        taxName: 'VAT',
        taxRate: 12.0,
        taxInclusive: true,
        tax: 0.0,
        grandTotal: total,
        amountReceived: amountReceived,
        change: change,
        items: items.map((item) {
          return ReceiptLine(
            name: (item['name'] ?? '').toString(),
            price: _toDouble(item['price']),
            qty: _toInt(item['qty']),
          );
        }).toList(),
      );

      if (!mounted) return;

      setState(() {
        _savingTransaction = false;
        _cartItems.clear();
        _liveSuggestions = [];
      });

      _searchController.clear();

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(
            data: receipt,
            receiptUrl: publicReceiptUrl,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingTransaction = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save transaction: $e')),
      );
    }
  }

  Future<Map<String, dynamic>?> _showPaymentSheet() async {
    final amountController = TextEditingController();

    String paymentMode;
    if (_acceptCashPayment) {
      paymentMode = 'Cash';
    } else if (_acceptGcashPayment) {
      paymentMode = 'GCash';
    } else {
      amountController.dispose();
      return null;
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final total = _cartTotal;
            final amountReceived =
                double.tryParse(amountController.text.trim()) ?? 0.0;
            final change = amountReceived - total;

            final enabledModes = <DropdownMenuItem<String>>[];
            if (_acceptCashPayment) {
              enabledModes.add(
                const DropdownMenuItem(value: 'Cash', child: Text('Cash')),
              );
            }
            if (_acceptGcashPayment) {
              enabledModes.add(
                const DropdownMenuItem(value: 'GCash', child: Text('GCash')),
              );
            }

            return Container(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                18 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF5FBFA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          '₱${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: _navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: paymentMode,
                    items: enabledModes,
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() {
                        paymentMode = value;
                        amountController.clear();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Payment Mode',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (paymentMode == 'Cash') ...[
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Amount Received',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Change',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          '₱${change.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: change < 0 ? Colors.red : _navy,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (paymentMode == 'GCash') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customer will scan this GCash QR',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: (_gcashQrImageUrl.trim().isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: InteractiveViewer(
                                        minScale: 1,
                                        maxScale: 4,
                                        child: Image.network(
                                          _gcashQrImageUrl,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) {
                                            return const Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.broken_image_outlined,
                                                    size: 40,
                                                    color: Colors.black45,
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    'Failed to load GCash QR image',
                                                    style: TextStyle(
                                                      color: Colors.black54,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    )
                                  : const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.qr_code_2_rounded,
                                            size: 42,
                                            color: Colors.black45,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'No GCash QR uploaded in Store Settings',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_gcashName.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                'Account Name: $_gcashName',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (_gcashNumber.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'GCash Number: $_gcashNumber',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          Text(
                            'Amount to Pay: ₱${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: _navy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Only press confirm after checking that the payment was received.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        final total = _cartTotal;

                        if (paymentMode == 'Cash') {
                          final amountReceived =
                              double.tryParse(amountController.text.trim()) ??
                                  0.0;

                          if (amountReceived <= 0) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text('Enter a valid amount first.'),
                              ),
                            );
                            return;
                          }

                          if (amountReceived < total) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text('Amount received is not enough.'),
                              ),
                            );
                            return;
                          }

                          Navigator.pop(sheetContext, {
                            'paymentMode': paymentMode,
                            'amountReceived': amountReceived,
                            'change': amountReceived - total,
                          });
                          return;
                        }

                        if (paymentMode == 'GCash') {
                          if (_gcashQrImageUrl.trim().isEmpty) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No GCash QR uploaded in Store Settings.',
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.pop(sheetContext, {
                            'paymentMode': paymentMode,
                            'amountReceived': total,
                            'change': 0.0,
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        paymentMode == 'GCash'
                            ? 'Confirm GCash Payment'
                            : 'Confirm Transaction',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    amountController.dispose();
    return result;
  }

  Widget _buildScannerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
          const Text(
            'Barcode Scanner',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 170,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: _softTeal),
                  MobileScanner(
                    controller: _scannerController,
                    fit: BoxFit.cover,
                    onDetect: _handleBarcodeDetection,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFB8E1DD)),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 220,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 3),
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(130),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Align barcode inside the frame',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (_addingByBarcode)
                    Container(
                      color: Colors.black.withAlpha(85),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showManualBarcodeDialog,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6A4FC8),
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Enter barcode manually',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: _updateLiveSuggestions,
                onSubmitted: (_) => _searchAndPickItem(),
                decoration: InputDecoration(
                  hintText: 'Search item name.',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _searchingItems ? null : _searchAndPickItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _searchingItems
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add Item'),
              ),
            ),
          ],
        ),
        if (_liveSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _liveSuggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = _liveSuggestions[index];
                final data = doc.data() ?? {};
                final name = _extractItemName(data);
                final category = _extractItemCategory(data);
                final price = _extractPrice(data);
                final stock = _extractStock(data);

                return ListTile(
                  title: Text(name),
                  subtitle: Text(
                    '${category.isEmpty ? 'Uncategorized' : category} • Stock: $stock • ₱${price.toStringAsFixed(2)}',
                  ),
                  onTap: () {
                    _addItemDocumentToCart(doc);
                    _searchController.clear();
                    setState(() => _liveSuggestions = []);
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCartList({
    bool shrinkWrap = false,
    ScrollPhysics? physics,
  }) {
    if (_cartItems.isEmpty) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 180),
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
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No items scanned yet',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
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
      child: ListView.separated(
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: const EdgeInsets.all(12),
        itemCount: _cartItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _cartItems[index];
          final name = item['name']?.toString() ?? 'Item';
          final price = _toDouble(item['price']);
          final qty = _toInt(item['qty']);
          final soldBy = item['soldBy']?.toString() ?? 'each';

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _softTeal,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBFE7E2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: _navy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₱${price.toStringAsFixed(2)} • $soldBy',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _decreaseQty(index),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    Text(
                      '$qty',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _increaseQty(index),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                    IconButton(
                      onPressed: () => _removeItem(index),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
          Row(
            children: [
              const Text(
                'Items',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '$_cartItemCount',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '₱${_cartTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: _navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _cartItems.isEmpty || _savingTransaction
                  ? null
                  : _proceedToTransact,
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.black12,
                disabledForegroundColor: Colors.black38,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _savingTransaction
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'TRANSACT',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitleName = _storeName?.trim();

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _pageBg,
        foregroundColor: Colors.black87,
        title: const Text(
          'Transaction',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildScannerCard(),
                          const SizedBox(height: 12),
                          _buildSearchRow(),
                          const SizedBox(height: 16),
                          Text(
                            'Transaction',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitleName == null || subtitleName.isEmpty
                                ? 'Scan/Add Item to transact...'
                                : 'Scan/Add Item to transact for $subtitleName...',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 12),
                          _buildCartList(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                          ),
                          const SizedBox(height: 12),
                          _buildBottomSummary(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
