import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/cloudinary_service.dart';
import 'barcode_scanner_screen.dart';

enum SoldBy { each, weight }

enum RepresentationType { color, image }

class CreateItemScreen extends StatefulWidget {
  const CreateItemScreen({super.key});

  @override
  State<CreateItemScreen> createState() => _CreateItemScreenState();
}

class _CreateItemScreenState extends State<CreateItemScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _stockQtyController = TextEditingController();

  SoldBy _soldBy = SoldBy.each;

  RepresentationType _representationType = RepresentationType.color;
  Color _selectedColor = const Color(0xFFD9D9D9);

  XFile? _pickedImage;
  Uint8List? _imageBytes;

  bool _isSaving = false;
  bool _loadingCategories = true;
  String? _storeId;
  List<String> _savedCategories = [];

  static const Color _teal = Color(0xFF0C7C86);
  static const Color _fieldFill = Color(0xFFF7F4F4);
  static const Color _fieldBorder = Color(0xFFD0D0D0);
  static const String _gradientAsset = 'assets/Gradient.png';

  final List<Color> _availableColors = const [
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
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _barcodeController.dispose();
    _stockQtyController.dispose();
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
      _categoryController.text = trimmed;

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
    if (user == null) {
      throw Exception('Not logged in. Please login again.');
    }

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final storeId = snap.data()?['storeId'] as String?;
    if (storeId == null || storeId.isEmpty) {
      throw Exception(
        'Missing storeId in users/${user.uid}. Add storeId to the user profile.',
      );
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
        _representationType = RepresentationType.image;
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
      _selectedColor = color;
      _representationType = RepresentationType.color;
      _pickedImage = null;
      _imageBytes = null;
    });
  }

  Future<Map<String, String>?> _uploadImageIfNeeded() async {
    if (_representationType != RepresentationType.image ||
        _pickedImage == null ||
        _imageBytes == null) {
      return null;
    }

    final res = await CloudinaryService.uploadBytes(
      bytes: _imageBytes!,
      filename: _pickedImage!.name,
    );

    final imageUrl = res['secure_url'] as String?;
    final publicId = res['public_id'] as String?;

    if (imageUrl == null || publicId == null) {
      throw Exception('Cloudinary response missing secure_url or public_id.');
    }

    return {
      'imageUrl': imageUrl,
      'imagePublicId': publicId,
    };
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
    if (n == null) return 'Enter a whole number';
    if (n < 0) return '$field cannot be negative';
    return null;
  }

  String _normalizeBarcode(String value) {
    return value.trim();
  }

  Future<void> _scanBarcodeIntoField() async {
    if (_isSaving) return;

    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(),
      ),
    );

    if (!mounted || code == null) return;

    final normalized = _normalizeBarcode(code);
    if (normalized.isEmpty) return;

    setState(() {
      _barcodeController.text = normalized;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Barcode captured: $normalized')),
    );
  }

  Future<bool> _barcodeExistsInStore({
    required String storeId,
    required String barcodeValue,
  }) async {
    if (barcodeValue.isEmpty) return false;

    final snap = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('items')
        .where('barcode', isEqualTo: barcodeValue)
        .limit(10)
        .get();

    return snap.docs.isNotEmpty;
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    if (_categoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category is required')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final storeId = _storeId ?? await _requireStoreId();

      final price = double.tryParse(_priceController.text.trim()) ?? 0;
      final cost = double.tryParse(_costController.text.trim()) ?? 0;
      final stockQty = int.tryParse(_stockQtyController.text.trim()) ?? 0;
      final barcodeValue = _normalizeBarcode(_barcodeController.text);

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

      final upload = await _uploadImageIfNeeded();
      final imageUrl = upload?['imageUrl'];
      final imagePublicId = upload?['imagePublicId'];

      final itemData = {
        'name': _nameController.text.trim(),
        'nameLower': _nameController.text.trim().toLowerCase(),
        'category': _categoryController.text.trim(),
        'soldBy': _soldBy == SoldBy.each ? 'each' : 'weight',
        'price': price,
        'cost': cost,
        'barcode': barcodeValue,
        'trackStock': true,
        'stockQty': stockQty,
        'representationType':
            _representationType == RepresentationType.color ? 'color' : 'image',
        'colorValue': _representationType == RepresentationType.color
            ? _selectedColor.value
            : null,
        'imageUrl':
            _representationType == RepresentationType.image ? imageUrl : null,
        'imagePublicId': _representationType == RepresentationType.image
            ? imagePublicId
            : null,
        'created_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('items')
          .add(itemData);

      _setCategory(_categoryController.text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item added successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving item: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showCategoryPicker() {
    final newCategoryController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose or type category',
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
                            _categoryController.text.trim().toLowerCase() ==
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2AA39A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        final value = newCategoryController.text.trim();
                        if (value.isEmpty) return;
                        _setCategory(value);
                        Navigator.pop(sheetContext);
                      },
                      child: const Text(
                        'USE CATEGORY',
                        style: TextStyle(color: Colors.white),
                      ),
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
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
                    children: _availableColors.map((color) {
                      final isSelected =
                          _representationType == RepresentationType.color &&
                              _selectedColor.value == color.value;

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
      fillColor: const Color(0xFFF7F4F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      hintStyle: const TextStyle(
        color: Colors.grey,
        fontSize: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
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
    return GestureDetector(
      onTap: _showRepresentationPicker,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _representationType == RepresentationType.color
                  ? _selectedColor
                  : Colors.grey.shade300,
              image: _representationType == RepresentationType.image &&
                      _imageBytes != null
                  ? DecorationImage(
                      image: MemoryImage(_imageBytes!),
                      fit: BoxFit.cover,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _representationType == RepresentationType.image &&
                    _imageBytes == null
                ? const Icon(Icons.image_outlined, color: Colors.grey, size: 34)
                : null,
          ),
          Positioned(
            right: -4,
            bottom: 6,
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
              child: const Icon(Icons.edit, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBubble({
    required double size,
  }) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.68,
        child: Image.asset(
          _gradientAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildSoldByOption({
    required String label,
    required SoldBy value,
  }) {
    final selected = _soldBy == value;

    return InkWell(
      onTap: () => setState(() => _soldBy = value),
      borderRadius: BorderRadius.circular(30),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _teal, width: 1.5),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: _teal,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryField() {
    final value = _categoryController.text.trim();

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
                    value.isEmpty ? 'Select or add category' : value,
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
          controller: _barcodeController,
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
                        _barcodeController.clear();
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
      backgroundColor: const Color(0xFFF0F4F6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 8),
                Center(child: _buildPreviewCircle()),
                const SizedBox(height: 28),
                _buildLabel('Product Name'),
                TextFormField(
                  controller: _nameController,
                  decoration: _fieldDecoration(
                    hintText: 'Product Name',
                    suffixIcon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  validator: (v) => _validateRequired(v, 'Product Name'),
                ),
                const SizedBox(height: 14),
                _buildCategoryField(),
                const SizedBox(height: 14),
                _buildLabel('Sold by'),
                Row(
                  children: [
                    _buildSoldByOption(label: 'Each', value: SoldBy.each),
                    const SizedBox(width: 34),
                    _buildSoldByOption(label: 'Weight', value: SoldBy.weight),
                  ],
                ),
                const SizedBox(height: 14),
                _buildLabel('Selling Price'),
                TextFormField(
                  controller: _priceController,
                  decoration: _fieldDecoration(hintText: 'Price'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _validateMoney(v, 'Selling Price'),
                ),
                const SizedBox(height: 14),
                _buildLabel('Cost'),
                TextFormField(
                  controller: _costController,
                  decoration: _fieldDecoration(hintText: 'Cost'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _validateMoney(v, 'Cost'),
                ),
                const SizedBox(height: 14),
                _buildLabel('Barcode'),
                TextFormField(
                  controller: _barcodeController,
                  decoration: _fieldDecoration(
                    hintText: '',
                    suffixIcon: const Icon(Icons.qr_code_2_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                _buildLabel('Stock Quantity'),
                TextFormField(
                  controller: _stockQtyController,
                  decoration: _fieldDecoration(hintText: 'Quantity..'),
                  keyboardType: TextInputType.number,
                  validator: (v) => _validateWholeNumber(v, 'Stock Quantity'),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveItem,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('CREATE ITEM'),
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
