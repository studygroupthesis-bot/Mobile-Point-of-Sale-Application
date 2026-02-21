import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/cloudinary_service.dart';

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
  final _costController = TextEditingController(); // ✅ NEW
  final _barcodeController = TextEditingController();
  final _stockQtyController = TextEditingController();

  SoldBy _soldBy = SoldBy.each;
  bool _trackStock = false;

  RepresentationType _representationType = RepresentationType.color;
  Color _selectedColor = Colors.green;

  XFile? _pickedImage;
  Uint8List? _imageBytes;

  bool _isSaving = false;

  final List<Color> _availableColors = const [
    Colors.grey,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.pink,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _costController.dispose(); // ✅ NEW
    _barcodeController.dispose();
    _stockQtyController.dispose();
    super.dispose();
  }

  Future<String> _requireStoreId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Not logged in. Please login again.");
    }

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final storeId = snap.data()?['storeId'] as String?;
    if (storeId == null || storeId.isEmpty) {
      throw Exception(
        "Missing storeId in users/${user.uid}. Add storeId to the user profile.",
      );
    }
    return storeId;
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _pickedImage = picked;
      _imageBytes = bytes;
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

    final imageUrl = res["secure_url"] as String?;
    final publicId = res["public_id"] as String?;

    if (imageUrl == null || publicId == null) {
      throw Exception("Cloudinary response missing secure_url or public_id.");
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

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final storeId = await _requireStoreId();

      final price = double.tryParse(_priceController.text.trim()) ?? 0;
      final cost = double.tryParse(_costController.text.trim()) ?? 0; // ✅ NEW

      final stockQty = int.tryParse(
            _stockQtyController.text.trim().isEmpty
                ? '0'
                : _stockQtyController.text.trim(),
          ) ??
          0;

      final upload = await _uploadImageIfNeeded();
      final imageUrl = upload?["imageUrl"];
      final imagePublicId = upload?["imagePublicId"];

      final itemData = {
        'name': _nameController.text.trim(),
        'category': _categoryController.text.trim(),
        'soldBy': _soldBy == SoldBy.each ? 'each' : 'weight',
        'price': price,
        'cost': cost, // ✅ NEW
        'barcode': _barcodeController.text.trim(),
        'trackStock': _trackStock,
        'stockQty': _trackStock ? stockQty : null,
        'representationType':
            _representationType == RepresentationType.color ? 'color' : 'image',
        'colorValue': _representationType == RepresentationType.color
            ? _selectedColor.toARGB32()
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

  Widget _buildSoldByRow() {
    return Row(
      children: [
        const Text('Sold by'),
        const SizedBox(width: 16),
        ChoiceChip(
          label: const Text('Each'),
          selected: _soldBy == SoldBy.each,
          onSelected: (_) => setState(() => _soldBy = SoldBy.each),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Weight'),
          selected: _soldBy == SoldBy.weight,
          onSelected: (_) => setState(() => _soldBy = SoldBy.weight),
        ),
      ],
    );
  }

  Widget _buildRepresentationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Representation'),
        const SizedBox(height: 8),
        RadioGroup<RepresentationType>(
          groupValue: _representationType,
          onChanged: (RepresentationType? value) {
            if (value == null) return;
            setState(() {
              _representationType = value;
              if (value == RepresentationType.color) {
                _pickedImage = null;
                _imageBytes = null;
              }
            });
          },
          child: const Row(
            children: [
              Radio<RepresentationType>(value: RepresentationType.color),
              Text('Color'),
              SizedBox(width: 16),
              Radio<RepresentationType>(value: RepresentationType.image),
              Text('Image'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_representationType == RepresentationType.color)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableColors.map((c) {
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = c),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      width: 2,
                      color: c == _selectedColor
                          ? Colors.black
                          : Colors.transparent,
                    ),
                  ),
                  child: c == _selectedColor
                      ? const Icon(Icons.check, size: 20, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                clipBehavior: Clip.antiAlias,
                child: _imageBytes == null
                    ? const Icon(Icons.image, size: 40)
                    : Image.memory(_imageBytes!, fit: BoxFit.cover),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.folder),
                    label: const Text('Choose Photo'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed:
                        kIsWeb ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ],
              ),
              if (kIsWeb)
                const Text(
                  "Camera is disabled on web preview. Use Choose Photo.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Item')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const Text(
                  'CREATE ITEM',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => _validateRequired(v, 'Name'),
                ),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),

                const SizedBox(height: 12),
                _buildSoldByRow(),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Selling Price'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _validateMoney(v, 'Selling Price'),
                ),

                // ✅ COST FIELD (Owner input)
                TextFormField(
                  controller: _costController,
                  decoration: const InputDecoration(
                    labelText: 'Cost (Purchase Price)',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _validateMoney(v, 'Cost'),
                ),

                TextFormField(
                  controller: _barcodeController,
                  decoration: const InputDecoration(
                    labelText: 'Barcode',
                    suffixIcon: Icon(Icons.qr_code_scanner),
                  ),
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Switch(
                      value: _trackStock,
                      onChanged: (val) => setState(() => _trackStock = val),
                    ),
                    const Text('Track Stock Quantity'),
                  ],
                ),
                if (_trackStock)
                  TextFormField(
                    controller: _stockQtyController,
                    decoration:
                        const InputDecoration(labelText: 'Stock Quantity'),
                    keyboardType: TextInputType.number,
                  ),

                const SizedBox(height: 16),
                _buildRepresentationSection(),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveItem,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add Item'),
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
