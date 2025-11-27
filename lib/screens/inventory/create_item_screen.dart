import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  File? _imageFile;

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

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImageIfNeeded() async {
    if (_representationType != RepresentationType.image || _imageFile == null) {
      return null;
    }

    final fileName =
        'items/${DateTime.now().millisecondsSinceEpoch}_${_nameController.text}.jpg';

    final ref = FirebaseStorage.instance.ref().child(fileName);
    final uploadTask = ref.putFile(_imageFile!);
    final snapshot = await uploadTask.whenComplete(() {});
    return snapshot.ref.getDownloadURL();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final price = double.tryParse(_priceController.text.trim()) ?? 0;
      final stockQty = int.tryParse(
            _stockQtyController.text.trim().isEmpty
                ? '0'
                : _stockQtyController.text.trim(),
          ) ??
          0;

      final imageUrl = await _uploadImageIfNeeded();

      final itemData = {
        'name': _nameController.text.trim(),
        'category': _categoryController.text.trim(),
        'soldBy': _soldBy == SoldBy.each ? 'each' : 'weight',
        'price': price,
        'barcode': _barcodeController.text.trim(),
        'trackStock': _trackStock,
        'stockQty': _trackStock ? stockQty : null,
        'representationType':
            _representationType == RepresentationType.color ? 'color' : 'image',
        'colorValue': _representationType == RepresentationType.color
            ? _selectedColor.value
            : null,
        'imageUrl':
            _representationType == RepresentationType.image ? imageUrl : null,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('items').add(itemData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added successfully')),
        );
        Navigator.pop(context); // go back to list screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving item: $e')));
      }
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
        Row(
          children: [
            Radio<RepresentationType>(
              value: RepresentationType.color,
              groupValue: _representationType,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _representationType = value);
              },
            ),
            const Text('Color'),
            const SizedBox(width: 16),
            Radio<RepresentationType>(
              value: RepresentationType.image,
              groupValue: _representationType,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _representationType = value);
              },
            ),
            const Text('Image'),
          ],
        ),
        const SizedBox(height: 8),
        if (_representationType == RepresentationType.color)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableColors
                .map(
                  (c) => GestureDetector(
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
                          ? const Icon(
                              Icons.check,
                              size: 20,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                )
                .toList(),
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
                child: _imageFile == null
                    ? const Icon(Icons.image, size: 40)
                    : Image.file(_imageFile!, fit: BoxFit.cover),
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
                    onPressed: () => _pickImage(ImageSource.camera),
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
                  validator: (value) => value == null || value.trim().isEmpty
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
                  validator: (value) => value == null || value.trim().isEmpty
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
                    decoration: const InputDecoration(
                      labelText: 'Stock Quantity',
                    ),
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
                        ? const CircularProgressIndicator()
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
