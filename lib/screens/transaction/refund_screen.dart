import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class RefundScreen extends StatefulWidget {
  final String? initialStoreId;
  final String? initialTransactionId;
  final String? initialInvoiceQuery;

  const RefundScreen({
    super.key,
    this.initialStoreId,
    this.initialTransactionId,
    this.initialInvoiceQuery,
  });

  @override
  State<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends State<RefundScreen> {
  final TextEditingController _invoiceController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _loadingStore = true;
  bool _findingTransaction = false;
  bool _processingRefund = false;
  bool _scannerOpen = false;
  bool _scannerBusy = false;

  String? _storeId;
  String? _storeName;

  DocumentSnapshot<Map<String, dynamic>>? _transactionDoc;
  Map<String, int> _alreadyRefundedByItem = {};

  static const Color _pageBg = Color(0xFFEAF6F4);
  static const Color _teal = Color(0xFF2F9E9C);
  static const Color _navy = Color(0xFF083B7A);

  @override
  void initState() {
    super.initState();
    _loadStoreContext().then((_) async {
      if (widget.initialTransactionId != null &&
          widget.initialTransactionId!.trim().isNotEmpty) {
        await _loadTransactionById(widget.initialTransactionId!.trim());
      } else if (widget.initialInvoiceQuery != null &&
          widget.initialInvoiceQuery!.trim().isNotEmpty) {
        _invoiceController.text = widget.initialInvoiceQuery!.trim();
        await _findTransactionByInvoice(_invoiceController.text.trim());
      }
    });
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _scannerController.dispose();
    super.dispose();
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

  String _toText(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _peso(double value) => '₱${value.toStringAsFixed(2)}';

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<void> _loadStoreContext() async {
    try {
      String? resolvedStoreId = widget.initialStoreId?.trim();

      if (resolvedStoreId == null || resolvedStoreId.isEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('Not logged in.');
        }

        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        resolvedStoreId = (userSnap.data()?['storeId'] as String?)?.trim();
        if (resolvedStoreId == null || resolvedStoreId.isEmpty) {
          throw Exception('No storeId found for current user.');
        }
      }

      final storeSnap = await FirebaseFirestore.instance
          .collection('stores')
          .doc(resolvedStoreId)
          .get();

      final storeData = storeSnap.data() ?? {};
      final resolvedStoreName =
          (storeData['business_name'] ?? storeData['storeName'] ?? 'Store')
              .toString();

      if (!mounted) return;
      setState(() {
        _storeId = resolvedStoreId;
        _storeName = resolvedStoreName;
        _loadingStore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load store: $e')),
      );
    }
  }

  Future<void> _loadAlreadyRefunded(String transactionId) async {
    final storeId = _storeId;
    if (storeId == null || storeId.isEmpty) return;

    final refundSnap = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('refunds')
        .where('transactionId', isEqualTo: transactionId)
        .get();

    final map = <String, int>{};

    for (final doc in refundSnap.docs) {
      final data = doc.data();
      final itemId = _toText(data['itemId']);
      final qty = _toInt(data['qtyRefunded']);
      if (itemId.isEmpty || qty <= 0) continue;
      map[itemId] = (map[itemId] ?? 0) + qty;
    }

    if (!mounted) return;
    setState(() {
      _alreadyRefundedByItem = map;
    });
  }

  Future<void> _loadTransactionById(String transactionId) async {
    final storeId = _storeId;
    if (storeId == null || storeId.isEmpty) return;

    setState(() => _findingTransaction = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('transactions')
          .doc(transactionId)
          .get();

      if (!mounted) return;

      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction not found.')),
        );
        setState(() {
          _transactionDoc = null;
          _alreadyRefundedByItem = {};
        });
        return;
      }

      setState(() {
        _transactionDoc = doc;
      });

      await _loadAlreadyRefunded(doc.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load transaction: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _findingTransaction = false);
      }
    }
  }

  Future<void> _findTransactionByInvoice(String rawInput) async {
    final storeId = _storeId;
    final query = rawInput.trim();

    if (storeId == null || storeId.isEmpty) return;

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter Receipt # or Invoice ID.')),
      );
      return;
    }

    setState(() => _findingTransaction = true);

    try {
      final txCollection = FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('transactions');

      final exactDoc = await txCollection.doc(query).get();
      if (exactDoc.exists) {
        if (!mounted) return;
        setState(() => _transactionDoc = exactDoc);
        await _loadAlreadyRefunded(exactDoc.id);
        return;
      }

      final invoiceIdSnap = await txCollection
          .where('invoiceId', isEqualTo: query)
          .limit(1)
          .get();

      if (invoiceIdSnap.docs.isNotEmpty) {
        final found = invoiceIdSnap.docs.first;
        if (!mounted) return;
        setState(() => _transactionDoc = found);
        await _loadAlreadyRefunded(found.id);
        return;
      }

      final invoiceNoSnap = await txCollection
          .where('invoiceNo', isEqualTo: query)
          .limit(1)
          .get();

      if (invoiceNoSnap.docs.isNotEmpty) {
        final found = invoiceNoSnap.docs.first;
        if (!mounted) return;
        setState(() => _transactionDoc = found);
        await _loadAlreadyRefunded(found.id);
        return;
      }

      final invoiceNoLowerSnap = await txCollection
          .where('invoiceNoLower', isEqualTo: query.toLowerCase())
          .limit(1)
          .get();

      if (invoiceNoLowerSnap.docs.isNotEmpty) {
        final found = invoiceNoLowerSnap.docs.first;
        if (!mounted) return;
        setState(() => _transactionDoc = found);
        await _loadAlreadyRefunded(found.id);
        return;
      }

      if (!mounted) return;
      setState(() {
        _transactionDoc = null;
        _alreadyRefundedByItem = {};
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No matching receipt found.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to find transaction: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _findingTransaction = false);
      }
    }
  }

  Future<void> _openScannerSheet() async {
    setState(() {
      _scannerOpen = true;
      _scannerBusy = false;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) async {
                    if (_scannerBusy) return;

                    final raw = capture.barcodes
                        .map((e) => e.rawValue?.trim() ?? '')
                        .firstWhere((e) => e.isNotEmpty, orElse: () => '');

                    if (raw.isEmpty) return;

                    _scannerBusy = true;

                    final parsed = _parseReceiptQr(raw);
                    if (parsed == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('QR is not a valid receipt QR.'),
                        ),
                      );
                      await Future.delayed(const Duration(milliseconds: 900));
                      _scannerBusy = false;
                      return;
                    }

                    if (Navigator.of(sheetContext).canPop()) {
                      Navigator.of(sheetContext).pop();
                    }

                    if (parsed['storeId'] != null &&
                        parsed['storeId']!.trim().isNotEmpty &&
                        _storeId != null &&
                        parsed['storeId'] != _storeId) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'This receipt belongs to a different store.',
                          ),
                        ),
                      );
                      _scannerBusy = false;
                      return;
                    }

                    final transactionId = parsed['transactionId'];
                    final invoiceQuery = parsed['invoiceQuery'];

                    if (transactionId != null && transactionId.isNotEmpty) {
                      await _loadTransactionById(transactionId);
                    } else if (invoiceQuery != null &&
                        invoiceQuery.isNotEmpty) {
                      _invoiceController.text = invoiceQuery;
                      await _findTransactionByInvoice(invoiceQuery);
                    }

                    _scannerBusy = false;
                  },
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 260,
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Text(
                    'Align the receipt QR inside the frame',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() => _scannerOpen = false);
  }

  Map<String, String?>? _parseReceiptQr(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final uri = Uri.tryParse(text);

    if (uri != null && (uri.hasScheme || text.contains('public-receipt'))) {
      final transactionId = uri.queryParameters['transactionId'];
      final storeId = uri.queryParameters['storeId'];
      final invoiceId = uri.queryParameters['invoiceId'];
      final invoiceNo = uri.queryParameters['invoiceNo'];

      return {
        'storeId': storeId,
        'transactionId': transactionId,
        'invoiceQuery': invoiceId ?? invoiceNo,
      };
    }

    return {
      'storeId': null,
      'transactionId': text,
      'invoiceQuery': text,
    };
  }

  Future<void> _showRefundDialog(Map<String, dynamic> item) async {
    final itemId = _toText(item['itemId']);
    final itemName = _toText(item['name'], fallback: 'Item');
    final soldQty = _toInt(item['qty']);
    final alreadyRefunded = _alreadyRefundedByItem[itemId] ?? 0;
    final refundableQty = soldQty - alreadyRefunded;
    final unitPrice = _toDouble(item['price']);

    if (refundableQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$itemName has no refundable quantity left.')),
      );
      return;
    }

    final qtyController = TextEditingController(text: '1');
    final reasonController = TextEditingController();
    bool restock = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Refund $itemName'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogInfo('Sold Qty', '$soldQty'),
                    _dialogInfo('Already Refunded', '$alreadyRefunded'),
                    _dialogInfo('Refundable Qty', '$refundableQty'),
                    _dialogInfo('Unit Price', _peso(unitPrice)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Qty to Refund',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: restock,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Return to stock'),
                      subtitle: const Text(
                        'Turn off if item is damaged or not restockable.',
                      ),
                      onChanged: (value) {
                        setModalState(() => restock = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                    final reason = reasonController.text.trim();

                    if (qty <= 0) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid refund quantity.'),
                        ),
                      );
                      return;
                    }

                    if (qty > refundableQty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Refund quantity cannot exceed $refundableQty.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (reason.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a refund reason.'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, {
                      'qty': qty,
                      'reason': reason,
                      'restock': restock,
                    });
                  },
                  child: const Text('Confirm Refund'),
                ),
              ],
            );
          },
        );
      },
    );

    qtyController.dispose();
    reasonController.dispose();

    if (result == null) return;

    await _processRefund(
      item: item,
      qtyToRefund: result['qty'] as int,
      reason: result['reason'] as String,
      restock: result['restock'] as bool,
    );
  }

  Widget _dialogInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Future<void> _processRefund({
    required Map<String, dynamic> item,
    required int qtyToRefund,
    required String reason,
    required bool restock,
  }) async {
    if (_transactionDoc == null) return;

    final storeId = _storeId;
    final user = FirebaseAuth.instance.currentUser;
    if (storeId == null || storeId.isEmpty || user == null) return;

    setState(() => _processingRefund = true);

    try {
      final db = FirebaseFirestore.instance;
      final txRef = _transactionDoc!.reference;

      final freshTx = await txRef.get();
      if (!freshTx.exists) {
        throw Exception('Original transaction no longer exists.');
      }

      final freshTxData = freshTx.data() ?? <String, dynamic>{};
      final transactionId = freshTx.id;
      final invoiceId =
          _toText(freshTxData['invoiceId'], fallback: transactionId);
      final invoiceNo =
          _toText(freshTxData['invoiceNo'], fallback: transactionId);

      final rawItems = freshTxData['items'];
      if (rawItems is! List) {
        throw Exception('Transaction items are missing or invalid.');
      }

      final List<Map<String, dynamic>> items =
          rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final itemId = _toText(item['itemId']);
      final itemName = _toText(item['name'], fallback: 'Item');
      final unitPrice = _toDouble(item['price']);

      final itemIndex = items.indexWhere((e) => _toText(e['itemId']) == itemId);
      if (itemIndex == -1) {
        throw Exception('Item not found in original transaction.');
      }

      final soldQty = _toInt(items[itemIndex]['qty']);
      final currentRefundedQty = _toInt(items[itemIndex]['refundedQty']);
      final refundableQty = soldQty - currentRefundedQty;

      if (qtyToRefund > refundableQty) {
        throw Exception('Refund quantity exceeds refundable quantity.');
      }

      items[itemIndex]['refundedQty'] = currentRefundedQty + qtyToRefund;

      final refundAmount =
          double.parse((unitPrice * qtyToRefund).toStringAsFixed(2));

      final currentRefundTotal = _toDouble(freshTxData['refundTotal']);
      final grossTotal = _toDouble(
        freshTxData['grossTotal'] ?? freshTxData['grandTotal'],
      );

      final newRefundTotal =
          double.parse((currentRefundTotal + refundAmount).toStringAsFixed(2));
      final newNetTotal =
          double.parse((grossTotal - newRefundTotal).toStringAsFixed(2));

      int stockBefore = 0;
      int stockAfter = 0;

      DocumentReference<Map<String, dynamic>>? itemRef;
      if (restock && itemId.isNotEmpty) {
        itemRef = db
            .collection('stores')
            .doc(storeId)
            .collection('items')
            .doc(itemId);

        final itemSnap = await itemRef.get();

        if (!itemSnap.exists) {
          throw Exception('Item document not found for restocking.');
        }

        final itemData = itemSnap.data() ?? <String, dynamic>{};
        stockBefore = _toInt(
          itemData['stockQty'] ??
              itemData['stock'] ??
              itemData['quantity'] ??
              0,
        );
        stockAfter = stockBefore + qtyToRefund;
      }

      final publicReceiptRef = db
          .collection('stores')
          .doc(storeId)
          .collection('public_receipts')
          .doc(transactionId);

      final publicReceiptSnap = await publicReceiptRef.get();

      final refundRef =
          db.collection('stores').doc(storeId).collection('refunds').doc();

      final stockLogRef =
          db.collection('stores').doc(storeId).collection('stock_logs').doc();

      final batch = db.batch();

      batch.update(txRef, {
        'items': items,
        'refundTotal': newRefundTotal,
        'netTotal': newNetTotal,
        'hasRefund': true,
        'refundedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (publicReceiptSnap.exists) {
        batch.update(publicReceiptRef, {
          'items': items,
          'refundTotal': newRefundTotal,
          'netTotal': newNetTotal,
          'hasRefund': true,
          'refundedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (restock && itemRef != null) {
        batch.update(itemRef, {
          'stockQty': stockAfter,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      batch.set(stockLogRef, {
        'itemId': itemId,
        'itemName': itemName,
        'type': restock ? 'refund_return' : 'refund_no_restock',
        'quantity': qtyToRefund,
        'stockBefore': stockBefore,
        'stockAfter': stockAfter,
        'costPrice': 0,
        'encodedByName': user.displayName ?? '',
        'encodedByEmail': user.email ?? '',
        'created_at': FieldValue.serverTimestamp(),
        'notes': restock
            ? 'Refunded from receipt $invoiceNo ($invoiceId). Reason: $reason'
            : 'Refunded without restock from receipt $invoiceNo ($invoiceId). Reason: $reason',
      });

      batch.set(refundRef, {
        'refundId': refundRef.id,
        'storeId': storeId,
        'transactionId': transactionId,
        'invoiceId': invoiceId,
        'invoiceNo': invoiceNo,
        'itemId': itemId,
        'productId': itemId,
        'productName': itemName,
        'itemName': itemName,
        'qtyRefunded': qtyToRefund,
        'unitPrice': unitPrice,
        'refundAmount': refundAmount,
        'reason': reason,
        'restock': restock,
        'processedByUid': user.uid,
        'processedByName': user.displayName ?? '',
        'processedByEmail': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtLocal': DateTime.now().toIso8601String(),
      });

      await batch.commit();
      await _loadTransactionById(transactionId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund processed successfully.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refund failed: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refund failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _processingRefund = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = _transactionDoc?.data() ?? {};
    final items = List<Map<String, dynamic>>.from(
      (tx['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );

    final createdAt =
        _readDate(tx['createdAt']) ?? _readDate(tx['createdAtLocal']);
    final invoiceId =
        _toText(tx['invoiceId'], fallback: _transactionDoc?.id ?? '-');
    final invoiceNo = _toText(tx['invoiceNo'], fallback: '-');
    final grossTotal = _toDouble(tx['grossTotal'] ?? tx['grandTotal']);
    final refundTotal = _toDouble(tx['refundTotal']);
    final netTotal = _toDouble(tx['netTotal'] ?? tx['grandTotal']);

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _pageBg,
        foregroundColor: Colors.black87,
        centerTitle: true,
        title: const Text(
          'Refund Item',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loadingStore
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
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
                        Text(
                          _storeName ?? 'Store',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Verify the original receipt before refunding.',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _invoiceController,
                                decoration: InputDecoration(
                                  hintText: 'Enter Receipt # or Invoice ID',
                                  filled: true,
                                  fillColor: const Color(0xFFF3F8F7),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _findingTransaction
                                    ? null
                                    : () => _findTransactionByInvoice(
                                          _invoiceController.text.trim(),
                                        ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _teal,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _findingTransaction
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Verify',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _scannerOpen ? null : _openScannerSheet,
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            label: const Text(
                              'Scan Receipt QR',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _navy,
                              side: const BorderSide(color: _navy),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_transactionDoc == null && !_findingTransaction)
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
                      child: const Text(
                        'No verified receipt yet.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  if (_transactionDoc != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
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
                            'Verified Receipt',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _infoRow('Invoice ID', invoiceId),
                          _infoRow('Invoice No', invoiceNo),
                          _infoRow(
                            'Date',
                            createdAt == null
                                ? '-'
                                : '${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}/${createdAt.year}',
                          ),
                          _infoRow('Gross Sales', _peso(grossTotal)),
                          _infoRow('Refunds', _peso(refundTotal)),
                          _infoRow('Net Sales', _peso(netTotal)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
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
                            'Items',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (items.isEmpty)
                            const Text(
                              'No items found in this transaction.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ...items.map((item) {
                            final itemId = _toText(item['itemId']);
                            final itemName =
                                _toText(item['name'], fallback: 'Item');
                            final qty = _toInt(item['qty']);
                            final refundedQty =
                                _alreadyRefundedByItem[itemId] ??
                                    _toInt(item['refundedQty']);
                            final refundableQty = qty - refundedQty;
                            final price = _toDouble(item['price']);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F8F7),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          itemName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _peso(price),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _navy,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(child: Text('Sold: $qty')),
                                      Expanded(
                                          child:
                                              Text('Refunded: $refundedQty')),
                                      Expanded(
                                          child: Text('Left: $refundableQty')),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: (_processingRefund ||
                                              refundableQty <= 0)
                                          ? null
                                          : () => _showRefundDialog(item),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _teal,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: Text(
                                        refundableQty <= 0
                                            ? 'Fully Refunded'
                                            : 'Refund This Item',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
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
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
