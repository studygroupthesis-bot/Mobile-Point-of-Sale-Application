import 'dart:typed_data';

import '../transaction/transaction_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final _businessCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _initialized = false;
  bool _saving = false;

  bool _acceptCash = true;
  bool _acceptGcash = false;

  String? _logoUrl; // from Firestore
  Uint8List? _pickedLogoBytes; // preview + upload (Web + Android)

  String? _lastStoreId; // to re-init if store changes

  @override
  void dispose() {
    _businessCtrl.dispose();
    _addressCtrl.dispose();
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
      // Storage might be disabled / requires billing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logo upload skipped: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _save(String storeId) async {
    setState(() => _saving = true);

    try {
      // Attempt upload only if user picked a logo
      final uploadedLogoUrl = await _tryUploadLogo(storeId);

      final payload = <String, dynamic>{
        'business_name': _businessCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'accept_cash': _acceptCash,
        'accept_gcash': _acceptGcash,
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
          _pickedLogoBytes = null; // clear preview after successful save
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

                if (storeId == null || storeId.isEmpty) {
                  return const Center(child: Text("No store linked."));
                }

                // If store changed (rare but safe), re-init
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

                    if (!(storeSnap.data!.exists)) {
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
                    final logoUrl = (storeData['logo_url'] as String?) ?? '';

                    // IMPORTANT: initialize ONLY after we have store data
                    if (!_initialized) {
                      _businessCtrl.text = businessName;
                      _addressCtrl.text = address;
                      _acceptCash = acceptCash;
                      _acceptGcash = acceptGcash;
                      _logoUrl = logoUrl.isEmpty ? null : logoUrl;
                      _initialized = true;
                    } else {
                      // keep logo reactive
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
                            GestureDetector(
                              onTap: _saving ? null : _pickLogo,
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: _pickedLogoBytes != null
                                    ? MemoryImage(_pickedLogoBytes!)
                                    : (_logoUrl != null && _logoUrl!.isNotEmpty)
                                        ? NetworkImage(_logoUrl!)
                                        : null,
                                child: (_pickedLogoBytes == null &&
                                        (_logoUrl == null || _logoUrl!.isEmpty))
                                    ? const Icon(Icons.store,
                                        size: 34, color: Colors.black54)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text("Tap logo to change",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                            const SizedBox(height: 16),
                            _field('Business Name', _businessCtrl),
                            _field('Business Address', _addressCtrl),
                            SwitchListTile(
                              title: const Text('Cash Payment'),
                              value: _acceptCash,
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() => _acceptCash = v),
                            ),
                            SwitchListTile(
                              title: const Text('GCash Payment'),
                              value: _acceptGcash,
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() => _acceptGcash = v),
                            ),
                            const Spacer(),
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
                                    _saving ? 'SAVING...' : 'SAVE CHANGES'),
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

  Widget _field(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.edit),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
