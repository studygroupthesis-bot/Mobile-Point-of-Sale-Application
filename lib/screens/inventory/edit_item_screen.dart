import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/cloudinary_service.dart';

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
  late TextEditingController barcode;
  late TextEditingController stockQty;

  SoldBy soldBy = SoldBy.each;
  bool trackStock = false;

  RepresentationType representation = RepresentationType.color;
  Color selectedColor = Colors.green;

  XFile? _pickedImage;
  Uint8List? _imageBytes;

  String? _existingImageUrl;
  // Kept only if you plan to delete old Cloudinary assets later.
  // If you don't use it, remove this field to avoid "unused" warnings.

  bool saving = false;

  final colors = const [
    Colors.grey,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.pink,
  ];

  Future<String> _requireStoreId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Not logged in. Please login again.");

    final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final storeId = snap.data()?['storeId'] as String?;
    if (storeId == null || storeId.isEmpty) {
      throw Exception("Missing storeId in users/${user.uid}.");
    }
    return storeId;
  }

  @override
  void initState() {
    super.initState();
    final d = widget.itemData;

    name = TextEditingController(text: d['name'] ?? '');
    category = TextEditingController(text: d['category'] ?? '');
    price = TextEditingController(text: d['price']?.toString() ?? '');
    barcode = TextEditingController(text: d['barcode'] ?? '');
    stockQty = TextEditingController(text: d['stockQty']?.toString() ?? '');

    soldBy = d['soldBy'] == 'weight' ? SoldBy.weight : SoldBy.each;
    trackStock = (d['trackStock'] as bool?) ?? false;

    representation =
        d['representationType'] == 'image' ? RepresentationType.image : RepresentationType.color;

    // Safe color parsing (avoids runtime type crash)
    final cv = d['colorValue'];
    if (cv is int) {
      selectedColor = Color(cv);
    } else if (cv is num) {
      selectedColor = Color(cv.toInt());
    }

  }

  @override
  void dispose() {
    name.dispose();
    category.dispose();
    price.dispose();
    barcode.dispose();
    stockQty.dispose();
    super.dispose();
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

  /// null => do not change image fields
  /// {"imageUrl":"", "imagePublicId":""} => clear image fields (switch to color)
  /// {"imageUrl":"...", "imagePublicId":"..."} => new image uploaded
  Future<Map<String, String>?> _uploadImageIfNeeded() async {
    if (representation != RepresentationType.image) {
      return {"imageUrl": "", "imagePublicId": ""};
    }

    // No new pick => keep existing fields as-is
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

  Future<void> updateItem() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);

    try {
      final storeId = await _requireStoreId();
      final uploaded = await _uploadImageIfNeeded();

      final updateData = <String, dynamic>{
        'name': name.text.trim(),
        'category': category.text.trim(),
        'price': double.tryParse(price.text.trim()) ?? 0,
        'barcode': barcode.text.trim(),
        'soldBy': soldBy == SoldBy.each ? 'each' : 'weight',
        'trackStock': trackStock,
        'representationType': representation == RepresentationType.color ? 'color' : 'image',
        // Avoid deprecated Color.value by using toARGB32
        'colorValue': representation == RepresentationType.color ? selectedColor.toARGB32() : null,
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Stock qty: store only if tracking stock
      if (trackStock) {
        updateData['stockQty'] = int.tryParse(stockQty.text.trim()) ?? 0;
      } else {
        updateData['stockQty'] = null;
      }

      // Image fields
      if (uploaded != null) {
        if (uploaded["imageUrl"]!.isEmpty) {
          // Switched to color (clear image)
          updateData['imageUrl'] = null;
          updateData['imagePublicId'] = null;
        } else {
          // New image uploaded
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final storeId = await _requireStoreId();

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

  Widget _colorSection() {
    return Wrap(
      spacing: 8,
      children: colors.map((c) {
        final isSelected = selectedColor == c;
        return GestureDetector(
          onTap: () => setState(() => selectedColor = c),
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
            child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _imageSection() {
    final hasPicked = _imageBytes != null;
    final hasExisting = (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);

    return Column(
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
          child: hasPicked
              ? Image.memory(_imageBytes!, fit: BoxFit.cover)
              : hasExisting
                  ? Image.network(_existingImageUrl!, fit: BoxFit.cover)
                  : const Icon(Icons.image, size: 40),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.folder),
              label: const Text("Choose Photo"),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: kIsWeb ? null : () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Take Photo"),
            ),
          ],
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
                const Text(
                  "EDIT ITEM",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: "Name"),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Name is required" : null,
                ),
                TextFormField(
                  controller: category,
                  decoration: const InputDecoration(labelText: "Category"),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    const Text("Sold by"),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text("Each"),
                      selected: soldBy == SoldBy.each,
                      onSelected: (_) => setState(() => soldBy = SoldBy.each),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text("Weight"),
                      selected: soldBy == SoldBy.weight,
                      onSelected: (_) => setState(() => soldBy = SoldBy.weight),
                    ),
                  ],
                ),

                TextFormField(
                  controller: price,
                  decoration: const InputDecoration(labelText: "Price"),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextFormField(
                  controller: barcode,
                  decoration: const InputDecoration(
                    labelText: "Barcode",
                    suffixIcon: Icon(Icons.qr_code_scanner),
                  ),
                ),

                const SizedBox(height: 12),
                SwitchListTile(
                  value: trackStock,
                  onChanged: (v) => setState(() => trackStock = v),
                  title: const Text("Track Stock Quantity"),
                ),
                if (trackStock)
                  TextFormField(
                    controller: stockQty,
                    decoration: const InputDecoration(labelText: "Stock Quantity"),
                    keyboardType: TextInputType.number,
                  ),

                const SizedBox(height: 16),
                const Text("Representation"),

                // ✅ Correct RadioGroup usage (wraps the Radio widgets)
                RadioGroup<RepresentationType>(
                  groupValue: representation,
                  onChanged: (RepresentationType? v) {
                    if (v == null) return;
                    setState(() {
                      representation = v;
                      if (v == RepresentationType.color) {
                        _pickedImage = null;
                        _imageBytes = null;
                      }
                    });
                  },
                  child: const Row(
                    children: [
                      Radio<RepresentationType>(value: RepresentationType.color),
                      Text("Color"),
                      SizedBox(width: 16),
                      Radio<RepresentationType>(value: RepresentationType.image),
                      Text("Image"),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                if (representation == RepresentationType.color) _colorSection(),
                if (representation == RepresentationType.image) _imageSection(),

                const SizedBox(height: 24),
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
                        : const Text("Save Changes"),
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
