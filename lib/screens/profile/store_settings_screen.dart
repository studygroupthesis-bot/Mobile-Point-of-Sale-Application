import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final _businessCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _gcashQrCtrl = TextEditingController();
  final _taxNameCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();

  bool _initialized = false;
  bool _saving = false;

  bool _acceptCash = true;
  bool _acceptGcash = false;

  bool _taxEnabled = false;
  bool _taxInclusive = true;

  String? _logoUrl;
  Uint8List? _pickedLogoBytes;

  String? _lastStoreId;

  @override
  void dispose() {
    _businessCtrl.dispose();
    _addressCtrl.dispose();
    _gcashQrCtrl.dispose();
    _taxNameCtrl.dispose();
    _taxRateCtrl.dispose();
    super.dispose();
  }

  Future<Uint8List> _compressJpegBytes(
    Uint8List inputBytes, {
    int maxWidth = 800,
    int quality = 75,
  }) async {
    final decoded = img.decodeImage(inputBytes);
    if (decoded == null) return inputBytes;

    img.Image processed = decoded;
    if (decoded.width > maxWidth) {
      processed = img.copyResize(decoded, width: maxWidth);
    }

    final jpg = img.encodeJpg(processed, quality: quality);
    return Uint8List.fromList(jpg);
  }

  Future<ImageSource?> _askSource(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLogo() async {
    final source = await _askSource(context);
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1400,
    );
    if (picked == null) return;

    final originalBytes = await picked.readAsBytes();
    final compressedBytes = await _compressJpegBytes(
      originalBytes,
      maxWidth: 800,
      quality: 75,
    );

    setState(() => _pickedLogoBytes = compressedBytes);
  }

  Future<String?> _tryUploadLogo(String storeId) async {
    if (_pickedLogoBytes == null) return null;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('stores')
          .child(storeId)
          .child('logo.jpg');

      await ref.putData(
        _pickedLogoBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await ref.getDownloadURL();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logo upload skipped: $e')),
        );
      }
      return null;
    }
  }

  double _safeToDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _save(String storeId) async {
    final taxRate = double.tryParse(_taxRateCtrl.text.trim());

    if (_taxEnabled) {
      if (_taxNameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a tax name.')),
        );
        return;
      }
      if (taxRate == null || taxRate < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid tax rate.')),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final uploadedLogoUrl = await _tryUploadLogo(storeId);

      final payload = <String, dynamic>{
        'business_name': _businessCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'accept_cash': _acceptCash,
        'accept_gcash': _acceptGcash,
        'gcashQrUrl': _gcashQrCtrl.text.trim(),
        'tax_enabled': _taxEnabled,
        'tax_name':
            _taxNameCtrl.text.trim().isEmpty ? 'VAT' : _taxNameCtrl.text.trim(),
        'tax_rate': taxRate ?? 12.0,
        'tax_inclusive': _taxInclusive,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (uploadedLogoUrl != null) {
        payload['logo_url'] = uploadedLogoUrl;
      }

      await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .set(payload, SetOptions(merge: true));

      if (uploadedLogoUrl != null) {
        setState(() {
          _logoUrl = uploadedLogoUrl;
          _pickedLogoBytes = null;
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store settings saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFE79A9A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title:
            const Text('Store Settings', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: uid == null
          ? const Center(child: Text("Not logged in."))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userData = userSnap.data!.data() ?? {};
                final storeId = userData['storeId'] as String?;
                final role = (userData['role'] as String?) ?? '';
                final isAdmin = role == 'admin';

                if (storeId == null || storeId.isEmpty) {
                  return const Center(child: Text("No store linked."));
                }

                if (!isAdmin) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline, size: 50),
                          SizedBox(height: 12),
                          Text(
                            'Only admin can edit store and tax settings.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (_lastStoreId != storeId) {
                  _lastStoreId = storeId;
                  _initialized = false;
                  _pickedLogoBytes = null;
                }

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('stores')
                      .doc(storeId)
                      .snapshots(),
                  builder: (context, storeSnap) {
                    if (!storeSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!storeSnap.data!.exists) {
                      return const Center(child: Text("Store not found."));
                    }

                    final storeData = storeSnap.data!.data() ?? {};

                    final businessName =
                        (storeData['business_name'] as String?) ?? '';
                    final address = (storeData['address'] as String?) ?? '';
                    final acceptCash =
                        (storeData['accept_cash'] as bool?) ?? true;
                    final acceptGcash =
                        (storeData['accept_gcash'] as bool?) ?? false;
                    final gcashQrUrl =
                        (storeData['gcashQrUrl'] as String?) ?? '';
                    final logoUrl = (storeData['logo_url'] as String?) ?? '';

                    final taxEnabled =
                        (storeData['tax_enabled'] as bool?) ?? false;
                    final taxName = (storeData['tax_name'] as String?) ?? 'VAT';
                    final taxRate =
                        _safeToDouble(storeData['tax_rate'], fallback: 12.0);
                    final taxInclusive =
                        (storeData['tax_inclusive'] as bool?) ?? true;

                    if (!_initialized) {
                      _businessCtrl.text = businessName;
                      _addressCtrl.text = address;
                      _gcashQrCtrl.text = gcashQrUrl;
                      _acceptCash = acceptCash;
                      _acceptGcash = acceptGcash;
                      _taxEnabled = taxEnabled;
                      _taxNameCtrl.text = taxName;
                      _taxRateCtrl.text = taxRate.toString();
                      _taxInclusive = taxInclusive;
                      _logoUrl = logoUrl.isEmpty ? null : logoUrl;
                      _initialized = true;
                    } else {
                      _logoUrl = logoUrl.isEmpty ? null : logoUrl;
                    }

                    return Center(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    GestureDetector(
                                      onTap: _saving ? null : _pickLogo,
                                      child: CircleAvatar(
                                        radius: 40,
                                        backgroundColor: Colors.grey.shade200,
                                        backgroundImage:
                                            _pickedLogoBytes != null
                                                ? MemoryImage(_pickedLogoBytes!)
                                                : (_logoUrl != null &&
                                                        _logoUrl!.isNotEmpty)
                                                    ? NetworkImage(_logoUrl!)
                                                    : null,
                                        child: (_pickedLogoBytes == null &&
                                                (_logoUrl == null ||
                                                    _logoUrl!.isEmpty))
                                            ? const Icon(
                                                Icons.store,
                                                size: 34,
                                                color: Colors.black54,
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "Tap logo to change",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _field('Business Name', _businessCtrl),
                                    _field('Business Address', _addressCtrl),
                                    const SizedBox(height: 10),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Payment Settings',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Cash Payment'),
                                      value: _acceptCash,
                                      onChanged: _saving
                                          ? null
                                          : (v) =>
                                              setState(() => _acceptCash = v),
                                    ),
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('GCash Payment'),
                                      value: _acceptGcash,
                                      onChanged: _saving
                                          ? null
                                          : (v) =>
                                              setState(() => _acceptGcash = v),
                                    ),
                                    if (_acceptGcash)
                                      _field('GCash QR URL', _gcashQrCtrl),
                                    const SizedBox(height: 10),
                                    const Divider(),
                                    const SizedBox(height: 10),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Tax Settings',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Enable Tax'),
                                      subtitle: const Text(
                                        'Show tax in transaction and receipt',
                                      ),
                                      value: _taxEnabled,
                                      onChanged: _saving
                                          ? null
                                          : (v) =>
                                              setState(() => _taxEnabled = v),
                                    ),
                                    if (_taxEnabled) ...[
                                      _field('Tax Name', _taxNameCtrl),
                                      _field(
                                        'Tax Rate (%)',
                                        _taxRateCtrl,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(
                                          decimal: true,
                                        ),
                                      ),
                                      SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('Inclusive Tax'),
                                        subtitle: const Text(
                                          'Customer total stays the same. Tax is extracted from the subtotal.',
                                        ),
                                        value: _taxInclusive,
                                        onChanged: _saving
                                            ? null
                                            : (v) => setState(
                                                  () => _taxInclusive = v,
                                                ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2AA39A),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                onPressed:
                                    _saving ? null : () => _save(storeId),
                                child: Text(
                                  _saving ? 'SAVING...' : 'SAVE CHANGES',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.edit),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
