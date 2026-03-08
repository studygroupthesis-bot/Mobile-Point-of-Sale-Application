import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddStockScreen extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> itemData;

  const AddStockScreen({
    super.key,
    required this.itemId,
    required this.itemData,
  });

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();

  final _quantityController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _notesController = TextEditingController();

  bool _saving = false;
  bool _hasExpiry = false;

  DateTime _receivedDate = DateTime.now();
  DateTime? _expiryDate;

  late final Future<_AddStockContext> _contextFuture;

  @override
  void initState() {
    super.initState();
    _contextFuture = _loadContext();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _costPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<_AddStockContext> _loadContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Not logged in.");
    }

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userSnap.data();
    final storeId = userData?['storeId'] as String?;

    if (storeId == null || storeId.isEmpty) {
      throw Exception(
        "Missing storeId in users/${user.uid}. Add storeId to the user profile.",
      );
    }

    return _AddStockContext(
      storeId: storeId,
      encodedByUid: user.uid,
      encodedByEmail:
          (userData?['email'] ?? user.email ?? 'No email').toString(),
      encodedByName: (userData?['name'] ?? 'Unknown User').toString(),
      encodedByRole: (userData?['role'] ?? 'staff').toString(),
    );
  }

  int _currentStock() {
    final stock = widget.itemData['stockQty'] ??
        widget.itemData['stock'] ??
        widget.itemData['quantity'] ??
        0;

    if (stock is int) return stock;
    return int.tryParse(stock.toString()) ?? 0;
  }

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$mm/$dd/$yyyy';
  }

  String _shortId(String id) {
    if (id.length <= 8) return id.toUpperCase();
    return id.substring(0, 8).toUpperCase();
  }

  String _yyyymmdd(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  String _makeBatchCode(String batchId, DateTime date) {
    return 'BATCH-${_yyyymmdd(date)}-${_shortId(batchId)}';
  }

  String _makeStockInCode(String logId, DateTime date) {
    return 'SI-${_yyyymmdd(date)}-${_shortId(logId)}';
  }

  Future<void> _pickReceivedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receivedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _receivedDate = picked;
      });
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? _receivedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _saveStockIn() async {
    if (!_formKey.currentState!.validate()) return;

    final quantity = int.tryParse(_quantityController.text.trim());
    final costPrice = double.tryParse(_costPriceController.text.trim());

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid stock quantity.')),
      );
      return;
    }

    if (_costPriceController.text.trim().isNotEmpty &&
        (costPrice == null || costPrice < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid cost price.')),
      );
      return;
    }

    if (_hasExpiry && _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expiry date.')),
      );
      return;
    }

    if (_hasExpiry && _expiryDate!.isBefore(_receivedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expiry date cannot be earlier than received date.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final ctx = await _contextFuture;
      final firestore = FirebaseFirestore.instance;

      final storeRef = firestore.collection('stores').doc(ctx.storeId);
      final itemRef = storeRef.collection('items').doc(widget.itemId);
      final batchRef = itemRef.collection('batches').doc();
      final logRef = storeRef.collection('stock_logs').doc();

      final nowDate = DateTime.now();
      final now = Timestamp.now();
      final itemName = (widget.itemData['name'] ?? 'Unnamed Item').toString();

      final batchCode = _makeBatchCode(batchRef.id, nowDate);
      final stockInCode = _makeStockInCode(logRef.id, nowDate);

      await firestore.runTransaction((transaction) async {
        final itemSnap = await transaction.get(itemRef);

        if (!itemSnap.exists) {
          throw Exception('Item no longer exists.');
        }

        final itemData = itemSnap.data() as Map<String, dynamic>;
        final currentStockRaw = itemData['stockQty'] ??
            itemData['stock'] ??
            itemData['quantity'] ??
            0;

        final currentStock = currentStockRaw is int
            ? currentStockRaw
            : int.tryParse(currentStockRaw.toString()) ?? 0;

        final newStock = currentStock + quantity;

        transaction.set(batchRef, {
          'batchId': batchRef.id,
          'batchCode': batchCode,
          'stockInCode': stockInCode,
          'itemId': widget.itemId,
          'itemName': itemName,
          'quantityAdded': quantity,
          'remainingQty': quantity,
          'costPrice': costPrice ?? 0,
          'notes': _notesController.text.trim(),
          'receivedDate': Timestamp.fromDate(_receivedDate),
          'hasExpiry': _hasExpiry,
          'expiryDate': _hasExpiry && _expiryDate != null
              ? Timestamp.fromDate(_expiryDate!)
              : null,
          'encodedByUid': ctx.encodedByUid,
          'encodedByEmail': ctx.encodedByEmail,
          'encodedByName': ctx.encodedByName,
          'encodedByRole': ctx.encodedByRole,
          'created_at': now,
          'updated_at': now,
        });

        transaction.update(itemRef, {
          'stockQty': newStock,
          'updated_at': now,
        });

        transaction.set(logRef, {
          'logId': logRef.id,
          'stockInCode': stockInCode,
          'batchId': batchRef.id,
          'batchCode': batchCode,
          'itemId': widget.itemId,
          'itemName': itemName,
          'type': 'stock_in',
          'quantity': quantity,
          'stockBefore': currentStock,
          'stockAfter': newStock,
          'costPrice': costPrice ?? 0,
          'notes': _notesController.text.trim(),
          'receivedDate': Timestamp.fromDate(_receivedDate),
          'hasExpiry': _hasExpiry,
          'expiryDate': _hasExpiry && _expiryDate != null
              ? Timestamp.fromDate(_expiryDate!)
              : null,
          'encodedByUid': ctx.encodedByUid,
          'encodedByEmail': ctx.encodedByEmail,
          'encodedByName': ctx.encodedByName,
          'encodedByRole': ctx.encodedByRole,
          'created_at': now,
        });
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock added successfully.')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add stock: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemName = (widget.itemData['name'] ?? 'Unnamed Item').toString();
    final currentStock = _currentStock();

    return Scaffold(
      backgroundColor: const Color(0xFFD78383),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD78383),
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Add Stock'),
      ),
      body: SafeArea(
        child: FutureBuilder<_AddStockContext>(
          future: _contextFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            }

            final ctx = snapshot.data!;

            return Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE6E6E6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8F0EC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.inventory_2_rounded),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Current Stock: $currentStock',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sectionTitle('Encoded By'),
                      const SizedBox(height: 8),
                      _infoTile(
                        title: ctx.encodedByName,
                        subtitle:
                            '${ctx.encodedByEmail} • ${ctx.encodedByRole}',
                      ),
                      const SizedBox(height: 14),
                      _sectionTitle('Stock Details'),
                      const SizedBox(height: 8),
                      _inputField(
                        controller: _quantityController,
                        label: 'Quantity to Add',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Quantity is required';
                          }
                          final qty = int.tryParse(value.trim());
                          if (qty == null || qty <= 0) {
                            return 'Enter a valid quantity';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      _inputField(
                        controller: _costPriceController,
                        label: 'Cost Price per Unit',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sectionTitle('Dates'),
                      const SizedBox(height: 8),
                      _dateTile(
                        label: 'Received Date',
                        value: _formatDate(_receivedDate),
                        onTap: _pickReceivedDate,
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _hasExpiry,
                        activeColor: Colors.teal,
                        title: const Text(
                          'Has Expiry Date',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _hasExpiry = value;
                            if (!value) {
                              _expiryDate = null;
                            }
                          });
                        },
                      ),
                      if (_hasExpiry) ...[
                        const SizedBox(height: 6),
                        _dateTile(
                          label: 'Expiry Date',
                          value: _expiryDate == null
                              ? 'Select date'
                              : _formatDate(_expiryDate!),
                          onTap: _pickExpiryDate,
                        ),
                      ],
                      const SizedBox(height: 14),
                      _sectionTitle('Notes'),
                      const SizedBox(height: 8),
                      _inputField(
                        controller: _notesController,
                        label: 'Notes',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.82),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Batch Code and Stock In Code will be generated automatically when you save.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveStockIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF59B8AA),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.3,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Stock In',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Widget _infoTile({
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? 'Unknown User' : title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withOpacity(0.82),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.82),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.calendar_today_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _AddStockContext {
  final String storeId;
  final String encodedByUid;
  final String encodedByEmail;
  final String encodedByName;
  final String encodedByRole;

  const _AddStockContext({
    required this.storeId,
    required this.encodedByUid,
    required this.encodedByEmail,
    required this.encodedByName,
    required this.encodedByRole,
  });
}
