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
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _stockQtyController = TextEditingController();

  final List<String> _categories = [
    'Beverages',
    'Snacks',
    'Pantry Supplies',
    'Personal Care',
    'Home Care',
    'Pharmacies',
  ];

  final List<Color> _availableColors = const [
    Colors.black,
    Colors.black54,
    Colors.grey,
    Colors.deepOrange,
    Colors.orange,
    Colors.amber,
    Colors.green,
    Colors.blue,
    Colors.deepPurpleAccent,
    Color(0xFFF8C7C7),
    Color(0xFFE2D3FF),
    Colors.white,
  ];

  String? _selectedCategory;
  SoldBy _soldBy = SoldBy.each;

  RepresentationType _representationType = RepresentationType.image;
  Color _selectedColor = const Color(0xFFD9D9D9);

  XFile? _pickedImage;
  Uint8List? _imageBytes;

  bool _isSaving = false;

  static const String _gradientAsset = 'assets/Gradient.png';

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _barcodeController.dispose();
    _stockQtyController.dispose();
    super.dispose();
  }

  Future<String> _requireStoreId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not logged in. Please login again.');
    }

    final snap =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final storeId = snap.data()?['storeId'] as String?;
    if (storeId == null || storeId.isEmpty) {
      throw Exception(
        'Missing storeId in users/${user.uid}. Add storeId to the user profile.',
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
      _representationType = RepresentationType.image;
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

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final storeId = await _requireStoreId();

      final price = double.tryParse(_priceController.text.trim()) ?? 0;
      final cost = double.tryParse(_costController.text.trim()) ?? 0;
      final stockQty = int.tryParse(_stockQtyController.text.trim()) ?? 0;

      final upload = await _uploadImageIfNeeded();
      final imageUrl = upload?['imageUrl'];
      final imagePublicId = upload?['imagePublicId'];

      final itemData = {
        'name': _nameController.text.trim(),
        'nameLower': _nameController.text.trim().toLowerCase(),
        'category': _selectedCategory ?? '',
        'soldBy': _soldBy == SoldBy.each ? 'each' : 'weight',
        'price': price,
        'cost': cost,
        'barcode': _barcodeController.text.trim(),
        'trackStock': true,
        'stockQty': stockQty,
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

  void _showRepresentationOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF2EEEE),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Colors'),
                  onTap: () {
                    Navigator.pop(context);
                    _showColorOptions();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Image'),
                  onTap: () {
                    Navigator.pop(context);
                    _showImageOptions();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showColorOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2EEEE),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: SafeArea(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _availableColors.map((color) {
                final isSelected = _selectedColor.value == color.value &&
                    _representationType == RepresentationType.color;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _representationType = RepresentationType.color;
                      _selectedColor = color;
                      _pickedImage = null;
                      _imageBytes = null;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.teal : Colors.black12,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: color == Colors.white
                        ? const Icon(Icons.circle_outlined,
                            size: 14, color: Colors.black26)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF2EEEE),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_outlined),
                  title: const Text('Upload'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take Photo'),
                  enabled: !kIsWeb,
                  onTap: kIsWeb
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await _pickImage(ImageSource.camera);
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSoldByRow() {
    return Row(
      children: [
        _soldByOption(
          label: 'Each',
          value: SoldBy.each,
        ),
        const SizedBox(width: 28),
        _soldByOption(
          label: 'Weight',
          value: SoldBy.weight,
        ),
      ],
    );
  }

  Widget _soldByOption({
    required String label,
    required SoldBy value,
  }) {
    final selected = _soldBy == value;

    return InkWell(
      onTap: () => setState(() => _soldBy = value),
      borderRadius: BorderRadius.circular(30),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF0C7B86),
                width: 2,
              ),
            ),
            child: selected
                ? const Center(
                    child: CircleAvatar(
                      radius: 6,
                      backgroundColor: Color(0xFF0C7B86),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.black38,
        fontSize: 16,
      ),
      filled: true,
      fillColor: const Color(0xFFF7F4F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF0C7B86), width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _buildPreviewCircle() {
    Widget child;

    if (_representationType == RepresentationType.color) {
      child = Container(color: _selectedColor);
    } else if (_imageBytes != null) {
      child = Image.memory(_imageBytes!, fit: BoxFit.cover);
    } else {
      child = Container(
        color: const Color(0xFFD9D9D9),
      );
    }

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  blurRadius: 8,
                  offset: Offset(0, 4),
                  color: Colors.black12,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
          Positioned(
            right: -4,
            bottom: -6,
            child: GestureDetector(
              onTap: _isSaving ? null : _showRepresentationOptions,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 4,
                      offset: Offset(0, 2),
                      color: Colors.black12,
                    ),
                  ],
                ),
                child: const Icon(Icons.edit, size: 18),
              ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F6),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: -120,
              top: 10,
              child: _buildGradientBubble(size: 320),
            ),
            Positioned(
              right: -125,
              top: 420,
              child: _buildGradientBubble(size: 280),
            ),
            Positioned(
              left: -115,
              bottom: -10,
              child: _buildGradientBubble(size: 250),
            ),
            Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Create Item',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildPreviewCircle(),
                  const SizedBox(height: 34),
                  const Text(
                    'Product Name',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nameController,
                    decoration: _fieldDecoration(
                      hint: 'Product Name',
                      suffixIcon: const Icon(Icons.edit_outlined),
                    ),
                    validator: (v) => _validateRequired(v, 'Product Name'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: _fieldDecoration(
                      hint: 'Select Category',
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    items: _categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Category is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sold by',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSoldByRow(),
                  const SizedBox(height: 16),
                  const Text(
                    'Barcode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _barcodeController,
                    decoration: _fieldDecoration(
                      hint: 'Barcode',
                      suffixIcon: const Icon(Icons.qr_code_scanner),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Stock Quantity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _stockQtyController,
                    decoration: _fieldDecoration(
                      hint: 'Quantity..',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => _validateRequired(v, 'Stock Quantity'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Selling Price',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _priceController,
                    decoration: _fieldDecoration(
                      hint: 'Selling Price',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) => _validateMoney(v, 'Selling Price'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Cost (Purchase Price)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _costController,
                    decoration: _fieldDecoration(
                      hint: 'Cost',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) => _validateMoney(v, 'Cost'),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2AA39A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'CREATE ITEM',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}