import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/cloudinary_service.dart';
import 'add_stock_screen.dart';
import '../../screens/transaction/barcode_scanner_screen.dart';

enum SoldBy { each, weight }

enum RepresentationType { color, image }

class EditItemScreen extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> itemData;

  const EditItemScreen({
    super.key,
    required this.itemId,
    required this.itemData,
  });

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController name;
  late TextEditingController category;
  late TextEditingController price;
  late TextEditingController cost;
  late TextEditingController barcode;
  late TextEditingController stockQty;

  SoldBy soldBy = SoldBy.each;

  RepresentationType representation = RepresentationType.color;
  Color selectedColor = const Color(0xFFD9D9D9);

  XFile? _pickedImage;
  Uint8List? _imageBytes;
  String? _existingImageUrl;

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
    final d = widget.itemData;

    name = TextEditingController(text: d['name'] ?? '');
    category = TextEditingController(text: d['category'] ?? '');
    price = TextEditingController(text: d['price']?.toString() ?? '');
    cost = TextEditingController(text: d['cost']?.toString() ?? '');
    barcode = TextEditingController(text: d['barcode'] ?? '');
    stockQty = TextEditingController(
      text: (d['stockQty'] ?? d['stock'] ?? d['quantity'] ?? 0).toString(),
    );

    soldBy = d['soldBy'] == 'weight' ? SoldBy.weight : SoldBy.each;

    representation = d['representationType'] == 'image'
        ? RepresentationType.image
        : RepresentationType.color;

    final cv = d['colorValue'];
    if (cv is int) {
      selectedColor = Color(cv);
    } else if (cv is num) {
      selectedColor = Color(cv.toInt());
    }

    _existingImageUrl = d['imageUrl'] as String?;

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

      final currentCategory = category.text.trim();
      if (currentCategory.isNotEmpty &&
          !categories.any(
            (c) => c.toLowerCase() == currentCategory.toLowerCase(),
          )) {
        categories.add(currentCategory);
        categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }

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
    if (user == null) throw Exception("Not logged in. Please login again.");

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

  Future<void> _refreshItemData() async {
    try {
      final storeId = _storeId ?? await _requireStoreId();

      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('items')
          .doc(widget.itemId)
          .get();

      if (!snap.exists || !mounted) return;

      final data = snap.data()!;

      setState(() {
        name.text = data['name']?.toString() ?? name.text;
        category.text = data['category']?.toString() ?? category.text;
        price.text = data['price']?.toString() ?? price.text;
        cost.text = data['cost']?.toString() ?? cost.text;
        barcode.text = data['barcode']?.toString() ?? barcode.text;
        stockQty.text =
            (data['stockQty'] ?? data['stock'] ?? data['quantity'] ?? 0)
                .toString();

        soldBy = data['soldBy'] == 'weight' ? SoldBy.weight : SoldBy.each;

        representation = data['representationType'] == 'image'
            ? RepresentationType.image
            : RepresentationType.color;

        final cv = data['colorValue'];
        if (cv is int) {
          selectedColor = Color(cv);
        } else if (cv is num) {
          selectedColor = Color(cv.toInt());
        }

        _existingImageUrl = data['imageUrl'] as String?;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to refresh item: $e")),
      );
    }
  }

  Future<void> _openAddStockScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddStockScreen(
          itemId: widget.itemId,
          itemData: {
            ...widget.itemData,
            'name': name.text.trim().isEmpty
                ? (widget.itemData['name'] ?? '')
                : name.text.trim(),
            'stockQty': int.tryParse(stockQty.text.trim()) ??
                (widget.itemData['stockQty'] ?? 0),
          },
        ),
      ),
    );

    if (result == true) {
      await _refreshItemData();
    }
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
        representation = RepresentationType.image;
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
      representation = RepresentationType.color;
      _pickedImage = null;
      _imageBytes = null;
    });
  }

  Future<Map<String, String>?> _uploadImageIfNeeded() async {
    if (representation != RepresentationType.image) {
      return {"imageUrl": "", "imagePublicId": ""};
    }

    if (_pickedImage == null || _imageBytes == null) return null;

    final res = await CloudinaryService.uploadBytes(
      bytes: _imageBytes!,
      filename: _pickedImage!.name,
    );

    final imageUrl = res["secure_url"] as String?;
    final publicId = res["public_id"] as String?;
    if (imageUrl == null || publicId == null) {
      throw Exception("Cloudinary response missing secure_url/public_id.");
    }

    return {"imageUrl": imageUrl, "imagePublicId": publicId};
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
    if (saving) return;

    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(),
      ),
    );

    if (!mounted || code == null) return;

    final normalized = _normalizeBarcode(code);
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
    required String ignoreItemId,
  }) async {
    if (barcodeValue.isEmpty) return false;

    final snap = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('items')
        .where('barcode', isEqualTo: barcodeValue)
        .limit(10)
        .get();

    for (final doc in snap.docs) {
      if (doc.id != ignoreItemId) {
        return true;
      }
    }

    return false;
  }

  Future<void> updateItem() async {
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
      final barcodeValue = _normalizeBarcode(barcode.text);

      if (barcodeValue.isNotEmpty) {
        final exists = await _barcodeExistsInStore(
          storeId: storeId,
          barcodeValue: barcodeValue,
          ignoreItemId: widget.itemId,
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

      final updateData = <String, dynamic>{
        'name': name.text.trim(),
        'nameLower': name.text.trim().toLowerCase(),
        'category': category.text.trim(),
        'price': double.tryParse(price.text.trim()) ?? 0,
        'cost': double.tryParse(cost.text.trim()) ?? 0,
        'barcode': barcodeValue,
        'soldBy': soldBy == SoldBy.each ? 'each' : 'weight',
        'trackStock': true,
        'stockQty': int.tryParse(stockQty.text.trim()) ?? 0,
        'representationType':
            representation == RepresentationType.color ? 'color' : 'image',
        'colorValue': representation == RepresentationType.color
            ? selectedColor.value
            : null,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (uploaded != null) {
        if (uploaded["imageUrl"]!.isEmpty) {
          updateData['imageUrl'] = null;
          updateData['imagePublicId'] = null;
        } else {
          updateData['imageUrl'] = uploaded["imageUrl"];
          updateData['imagePublicId'] = uploaded["imagePublicId"];
        }
      }

      await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('items')
          .doc(widget.itemId)
          .update(updateData);

      _setCategory(category.text);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating item: $e")),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> deleteItem() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Item"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final storeId = _storeId ?? await _requireStoreId();

      await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('items')
          .doc(widget.itemId)
          .delete();

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting item: $e")),
      );
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
                        trailing: category.text.trim().toLowerCase() ==
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
                          representation == RepresentationType.color &&
                              selectedColor.value == color.value;

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
    final hasPicked = _imageBytes != null;
    final hasExisting =
        _existingImageUrl != null && _existingImageUrl!.trim().isNotEmpty;

    ImageProvider? imageProvider;
    if (representation == RepresentationType.image) {
      if (hasPicked) {
        imageProvider = MemoryImage(_imageBytes!);
      } else if (hasExisting) {
        imageProvider = NetworkImage(_existingImageUrl!);
      }
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
              color: representation == RepresentationType.color
                  ? selectedColor
                  : Colors.grey.shade300,
              image: imageProvider != null
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: imageProvider == null &&
                    representation == RepresentationType.image
                ? const Icon(Icons.image_outlined, color: Colors.grey, size: 30)
                : null,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12),
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
    required SoldBy value,
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

  Widget _buildStockActionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Current Stock Quantity'),
        TextFormField(
          controller: stockQty,
          readOnly: true,
          decoration: _fieldDecoration(
            hintText: 'Quantity',
            suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
          ).copyWith(
            helperText:
                'Use Add Stock for new deliveries so batch details and stock logs are saved.',
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: saving ? null : _openAddStockScreen,
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('ADD STOCK'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _teal,
              side: const BorderSide(color: _teal),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Item"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: deleteItem,
          ),
        ],
      ),
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
                  controller: name,
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
                  controller: price,
                  decoration: _fieldDecoration(hintText: 'Price'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _validateMoney(v, 'Selling Price'),
                ),
                const SizedBox(height: 14),
                _buildLabel('Cost'),
                TextFormField(
                  controller: cost,
                  decoration: _fieldDecoration(hintText: 'Cost'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _validateMoney(v, 'Cost'),
                ),
                const SizedBox(height: 14),
                _buildBarcodeField(),
                const SizedBox(height: 14),
                _buildStockActionSection(),
                const SizedBox(height: 28),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: saving ? null : updateItem,
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("SAVE CHANGES"),
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
