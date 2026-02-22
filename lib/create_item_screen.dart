import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
    _barcodeController.dispose();
    _stockQtyController.dispose();
    super.dispose();
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

  /// ✅ One upload function: works on Web + Mobile (no dart:io)
  Future<String?> _uploadImageBytes({required String storeId}) async {
    if (_representationType != RepresentationType.image) return null;
    if (_pickedImage == null || _imageBytes == null) return null;

    final safeName = _nameController.text.trim().replaceAll(' ', '_');
    final fileName =
        'stores/$storeId/items/${DateTime.now().millisecondsSinceEpoch}_$safeName.jpg';

    final ref = FirebaseStorage.instance.ref().child(fileName);
    final meta = SettableMetadata(contentType: 'image/jpeg');

    final snap = await ref.putData(_imageBytes!, meta);
    return snap.ref.getDownloadURL();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final storeId = await _requireStoreId();

      final price = double.tryParse(_priceController.text.trim()) ?? 0;
      final stockQty = int.tryParse(
            _stockQtyController.text.trim().isEmpty
                ? '0'
                : _stockQtyController.text.trim(),
          ) ??
          0;

      final imageUrl = await _uploadImageBytes(storeId: storeId);

      final itemData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'nameLower': _nameController.text.trim().toLowerCase(),
        'category': _categoryController.text.trim(),
        'soldBy': _soldBy == SoldBy.each ? 'each' : 'weight',
        'price': price,
        'barcode': _barcodeController.text.trim(),
        'trackStock': _trackStock,
        'stockQty': _trackStock ? stockQty : null,
        'representationType':
            _representationType == RepresentationType.color ? 'color' : 'image',

        // ✅ FIX: Color.value deprecated
        'colorValue': _representationType == RepresentationType.color
            ? _selectedColor.toARGB32()
            : null,

        'imageUrl':
            _representationType == RepresentationType.image ? imageUrl : null,
        'createdAt': FieldValue.serverTimestamp(),
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

        // ✅ FIX: nullable-safe onChanged
        RadioGroup<RepresentationType>(
          groupValue: _representationType,
          onChanged: (RepresentationType? v) {
            if (v == null) return;
            setState(() {
              _representationType = v;
              if (v == RepresentationType.color) {
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
              final isSelected = c == _selectedColor;
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
                      color: isSelected ? Colors.black : Colors.transparent,
                    ),
                  ),
                  child: isSelected
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
                  border: Border.all(color: Colors.grey),
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
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
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
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Price is required'
                      : null,
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
