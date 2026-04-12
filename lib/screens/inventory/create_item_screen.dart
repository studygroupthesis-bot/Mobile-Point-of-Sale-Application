import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:pos_system/screens/inventory/barcode_scanner_screen.dart';
import 'package:pos_system/services/cloudinary_service.dart';

enum _SoldBy { each, weight }

enum _RepresentationType { color, image }

class CreateItemScreen extends StatefulWidget {
  const CreateItemScreen({super.key});

  @override
  State<CreateItemScreen> createState() => _CreateItemScreenState();
}

class _CreateItemScreenState extends State<CreateItemScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController name = TextEditingController();
  final TextEditingController category = TextEditingController();
  final TextEditingController price = TextEditingController();
  final TextEditingController cost = TextEditingController();
  final TextEditingController barcode = TextEditingController();
  final TextEditingController stockQty = TextEditingController(text: '0');

  _SoldBy soldBy = _SoldBy.each;

  _RepresentationType representation = _RepresentationType.color;
  Color selectedColor = const Color(0xFFD9D9D9);

  XFile? _pickedImage;
  Uint8List? _imageBytes;

  bool saving = false;
  bool _loadingCategories = true;
  String? _storeId;
  List<String> _savedCategories = [];

  static const Color _teal = Color(0xFF0C7C86);
  static const Color _fieldFill = Color(0xFFE6E6E6);
  static const Color _fieldBorder = Color(0xFFD0D0D0);

  final colors = const [
    Colors.grey,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.pink,
    Colors.purple,
    Colors.brown,
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _loadStoreAndCategories();
  }

  @override
  void dispose() {
    name.dispose();
    category.dispose();
    price.dispose();
    cost.dispose();
    barcode.dispose();
    stockQty.dispose();
    super.dispose();
  }

  Future<void> _loadStoreAndCategories() async {
    try {
      final storeId = await _requireStoreId();
      final categories = await _fetchSavedCategories(storeId);

      if (!mounted) return;
      setState(() {
        _storeId = storeId;
        _savedCategories = categories;
        _loadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCategories = false;
      });
    }
  }

  Future<List<String>> _fetchSavedCategories(String storeId) async {
    final snap = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('items')
        .get();

    final set = <String>{};

    for (final doc in snap.docs) {
      final value = (doc.data()['category'] as String?)?.trim();
      if (value != null && value.isNotEmpty) {
        set.add(value);
      }
    }

    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return list;
  }

  bool _hasCategory(String value) {
    return _savedCategories.any(
      (cat) => cat.toLowerCase() == value.trim().toLowerCase(),
    );
  }

  void _setCategory(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      category.text = trimmed;

      if (!_hasCategory(trimmed)) {
        _savedCategories.add(trimmed);
        _savedCategories.sort(
          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
        );
      }
    });
  }

  Future<String> _requireStoreId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in. Please login again.');

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 80);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImage = picked;
        _imageBytes = bytes;
        representation = _RepresentationType.image;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  void _selectColor(Color color) {
    setState(() {
      selectedColor = color;
      representation = _RepresentationType.color;
      _pickedImage = null;
      _imageBytes = null;
    });
  }

  Future<Map<String, String>?> _uploadImageIfNeeded() async {
    if (representation != _RepresentationType.image) {
      return {'imageUrl': '', 'imagePublicId': ''};
    }

    if (_pickedImage == null || _imageBytes == null) return null;

    final res = await CloudinaryService.uploadBytes(
      bytes: _imageBytes!,
      filename: _pickedImage!.name,
    );

    final imageUrl = res['secure_url'] as String?;
    final publicId = res['public_id'] as String?;
    if (imageUrl == null || publicId == null) {
      throw Exception('Cloudinary response missing secure_url/public_id.');
    }

    return {'imageUrl': imageUrl, 'imagePublicId': publicId};
  }

  String? _validateRequired(String? value, String field) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  String? _validateMoney(String? value, String field) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    final n = double.tryParse(value.trim());
    if (n == null) return 'Enter a valid number';
    if (n < 0) return '$field cannot be negative';
    return null;
  }

  String? _validateWholeNumber(String? value, String field) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    final n = int.tryParse(value.trim());
    if (n == null) return 'Enter a valid whole number';
    if (n < 0) return '$field cannot be negative';
    return null;
  }

  String _normalizeBarcodeValue(dynamic value) {
    if (value == null) return '';
    var text = value.toString().trim().replaceAll(RegExp(r'\s+'), '');
    if (text.endsWith('.0')) {
      text = text.substring(0, text.length - 2);
    }
    return text;
  }

  Future<void> _scanBarcodeIntoField() async {
    if (saving) return;

    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(),
      ),
    );

    if (!mounted || code == null) return;

    final normalized = _normalizeBarcodeValue(code);
    if (normalized.isEmpty) return;

    setState(() {
      barcode.text = normalized;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Barcode captured: $normalized')),
    );
  }

  Future<bool> _barcodeExistsInStore({
    required String storeId,
    required String barcodeValue,
  }) async {
    final normalized = _normalizeBarcodeValue(barcodeValue);
    if (normalized.isEmpty) return false;

    final itemsRef = FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('items');

    final exact =
        await itemsRef.where('barcode', isEqualTo: normalized).limit(1).get();

    if (exact.docs.isNotEmpty) return true;

    final exactNormalized = await itemsRef
        .where('barcodeNormalized', isEqualTo: normalized)
        .limit(1)
        .get();

    if (exactNormalized.docs.isNotEmpty) return true;

    final all = await itemsRef.get();
    for (final doc in all.docs) {
      final saved = _normalizeBarcodeValue(doc.data()['barcode']);
      if (saved == normalized) return true;
    }

    return false;
  }

  Future<void> createItem() async {
    if (!_formKey.currentState!.validate()) return;

    if (category.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category is required')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final storeId = _storeId ?? await _requireStoreId();
      final barcodeValue = _normalizeBarcodeValue(barcode.text);
      final initialStock = int.tryParse(stockQty.text.trim()) ?? 0;

      if (barcodeValue.isNotEmpty) {
        final exists = await _barcodeExistsInStore(
          storeId: storeId,
          barcodeValue: barcodeValue,
        );

        if (exists) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Barcode already exists for another item.'),
            ),
          );
          return;
        }
      }

      final uploaded = await _uploadImageIfNeeded();

      final user = FirebaseAuth.instance.currentUser;
      final payload = <String, dynamic>{
        'name': name.text.trim(),
        'nameLower': name.text.trim().toLowerCase(),
        'category': category.text.trim(),
        'price': double.tryParse(price.text.trim()) ?? 0,
        'cost': double.tryParse(cost.text.trim()) ?? 0,
        'barcode': barcodeValue,
        'barcodeNormalized': barcodeValue,
        'soldBy': soldBy == _SoldBy.each ? 'each' : 'weight',
        'trackStock': true,
        'stockQty': initialStock,
        'stock': initialStock,
        'quantity': initialStock,
        'representationType':
            representation == _RepresentationType.color ? 'color' : 'image',
        'colorValue': representation == _RepresentationType.color
            ? selectedColor.toARGB32()
            : null,
        'imageUrl': null,
        'imagePublicId': null,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'createdByUid': user?.uid,
        'storeId': storeId,
      };

      if (uploaded != null && uploaded['imageUrl']!.isNotEmpty) {
        payload['imageUrl'] = uploaded['imageUrl'];
        payload['imagePublicId'] = uploaded['imagePublicId'];
      }

      await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('items')
          .add(payload);

      _setCategory(category.text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item created successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating item: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _showCategoryPicker() {
    final newCategoryController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  if (_loadingCategories)
                    const Center(child: CircularProgressIndicator())
                  else if (_savedCategories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'No saved categories yet. You can type a new one.',
                      ),
                    )
                  else
                    ..._savedCategories.map(
                      (cat) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(cat),
                        trailing:
                            category.text.trim().toLowerCase() ==
                                    cat.toLowerCase()
                                ? const Icon(Icons.check, color: _teal)
                                : null,
                        onTap: () {
                          _setCategory(cat);
                          Navigator.pop(sheetContext);
                        },
                      ),
                    ),
                  const Divider(height: 28),
                  const Text(
                    'Add New Category',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newCategoryController,
                    decoration: InputDecoration(
                      hintText: 'Type new category',
                      filled: true,
                      fillColor: _fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _fieldBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _fieldBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        final value = newCategoryController.text.trim();
                        if (value.isEmpty) return;
                        _setCategory(value);
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('USE CATEGORY'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRepresentationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose Item Display',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Colors',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: colors.map((color) {
                      final isSelected =
                          representation == _RepresentationType.color &&
                              selectedColor.toARGB32() == color.toARGB32();

                      return GestureDetector(
                        onTap: () {
                          _selectColor(color);
                          Navigator.pop(sheetContext);
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: 2,
                              color: isSelected
                                  ? Colors.black
                                  : Colors.transparent,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Image',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.upload),
                    title: const Text('Upload'),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _pickImage(ImageSource.gallery);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.camera_alt_outlined),
                    title: const Text('Take Photo'),
                    onTap: kIsWeb
                        ? null
                        : () async {
                            Navigator.pop(sheetContext);
                            await _pickImage(ImageSource.camera);
                          },
                  ),
                  if (kIsWeb)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Camera is disabled on web preview. Use Upload.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _teal, width: 1.2),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }

  Widget _buildPreviewCircle() {
    ImageProvider? imageProvider;
    if (representation == _RepresentationType.image && _imageBytes != null) {
      imageProvider = MemoryImage(_imageBytes!);
    }

    return GestureDetector(
      onTap: _showRepresentationPicker,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: representation == _RepresentationType.color
                  ? selectedColor
                  : Colors.grey.shade300,
              image: imageProvider != null
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child:
                imageProvider == null &&
                        representation == _RepresentationType.image
                    ? const Icon(
                        Icons.image_outlined,
                        color: Colors.grey,
                        size: 30,
                      )
                    : null,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.edit, size: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoldByOption({
    required String label,
    required _SoldBy value,
  }) {
    final selected = soldBy == value;

    return InkWell(
      onTap: () => setState(() => soldBy = value),
      borderRadius: BorderRadius.circular(30),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _teal, width: 1.4),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: const BoxDecoration(
                        color: _teal,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildCategoryField() {
    final value = category.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Category'),
        InkWell(
          onTap: _showCategoryPicker,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _fieldFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _fieldBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value.isEmpty ? 'Choose or type category' : value,
                    style: TextStyle(
                      color: value.isEmpty ? Colors.grey : Colors.black87,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarcodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Barcode'),
        TextFormField(
          controller: barcode,
          decoration: _fieldDecoration(
            hintText: 'Scan or enter barcode',
            suffixIcon: SizedBox(
              width: 96,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Scan barcode',
                    onPressed: _scanBarcodeIntoField,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                  ),
                  IconButton(
                    tooltip: 'Clear barcode',
                    onPressed: () {
                      setState(() {
                        barcode.clear();
                      });
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Optional, but barcode should be unique per item.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Create Item'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF1F4F4),
                    Color(0xFFDDF3EF),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  const SizedBox(height: 8),
                  Center(child: _buildPreviewCircle()),
                  const SizedBox(height: 28),

                  _buildLabel('Product Name'),
                  TextFormField(
                    controller: name,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      hintText: 'Product Name',
                      suffixIcon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                    validator: (v) => _validateRequired(v, 'Product Name'),
                  ),

                  const SizedBox(height: 14),
                  _buildCategoryField(),

                  const SizedBox(height: 14),
                  _buildLabel('Price'),
                  TextFormField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      hintText: '0.00',
                      suffixIcon: const Icon(Icons.payments_outlined, size: 18),
                    ),
                    validator: (v) => _validateMoney(v, 'Price'),
                  ),

                  const SizedBox(height: 14),
                  _buildLabel('Cost'),
                  TextFormField(
                    controller: cost,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      hintText: '0.00',
                      suffixIcon:
                          const Icon(Icons.receipt_long_outlined, size: 18),
                    ),
                    validator: (v) => _validateMoney(v, 'Cost'),
                  ),

                  const SizedBox(height: 14),
                  _buildBarcodeField(),

                  const SizedBox(height: 14),
                  _buildLabel('Initial Stock Quantity'),
                  TextFormField(
                    controller: stockQty,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: _fieldDecoration(
                      hintText: '0',
                      suffixIcon:
                          const Icon(Icons.inventory_2_outlined, size: 18),
                    ),
                    validator: (v) =>
                        _validateWholeNumber(v, 'Initial Stock Quantity'),
                  ),

                  const SizedBox(height: 14),
                  _buildLabel('Sold by'),
                  Row(
                    children: [
                      _buildSoldByOption(label: 'Each', value: _SoldBy.each),
                      const SizedBox(width: 34),
                      _buildSoldByOption(
                        label: 'Weight',
                        value: _SoldBy.weight,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: saving ? null : createItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'CREATE ITEM',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}