import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../firebase/store_members_services.dart';

class AddEditUserScreen extends StatefulWidget {
  final String storeId;
  final String? memberUid; // null = add, not null = edit

  const AddEditUserScreen({
    super.key,
    required this.storeId,
    this.memberUid,
  });

  @override
  State<AddEditUserScreen> createState() => _AddEditUserScreenState();
}

class _AddEditUserScreenState extends State<AddEditUserScreen> {
  final _svc = StoreMembersService();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _role = 'staff';
  bool _saving = false;
  bool _initialized = false;

  bool get isEdit => widget.memberUid != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _memberStream() {
    if (!isEdit) return null;
    return FirebaseFirestore.instance
        .collection('stores')
        .doc(widget.storeId)
        .collection('members')
        .doc(widget.memberUid!)
        .snapshots();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (isEdit) {
        await _svc.updateMember(
          storeId: widget.storeId,
          uid: widget.memberUid!,
          name: name,
          phone: phone,
          role: _role,
        );
      } else {
        if (email.isEmpty || pass.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email and Password are required')),
          );
          return;
        }

        await _svc.createStaff(
          storeId: widget.storeId,
          name: name,
          email: email,
          password: pass,
          phone: phone,
          role: _role,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!isEdit) return;

    final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Remove user?'),
            content: const Text(
              'This removes the staff from this store list. '
              'It does NOT delete their Firebase Auth account.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    setState(() => _saving = true);
    try {
      await _svc.deleteMember(storeId: widget.storeId, uid: widget.memberUid!);
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE79A9A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(isEdit ? 'Edit User' : 'Add User',
            style: const TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          if (isEdit)
            IconButton(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline, color: Colors.black),
            ),
        ],
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: isEdit
              ? StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _memberStream(),
                  builder: (context, snap) {
                    final data = snap.data?.data() ?? {};
                    if (!_initialized && snap.hasData) {
                      _nameCtrl.text = (data['name'] as String?) ?? '';
                      _emailCtrl.text = (data['email'] as String?) ?? '';
                      _phoneCtrl.text = (data['phone'] as String?) ?? '';
                      _role = (data['role'] as String?) ?? 'staff';
                      _initialized = true;
                    }
                    return _form(context, lockEmail: true);
                  },
                )
              : _form(context, lockEmail: false),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, {required bool lockEmail}) {
    return Column(
      children: [
        // No profile photo header (as requested)
        _field('Name', _nameCtrl, enabled: !_saving),
        _field('Email Address', _emailCtrl,
            enabled: !lockEmail && !_saving, lockIcon: lockEmail),
        if (!isEdit)
          _field('Password', _passCtrl, enabled: !_saving, obscure: true),
        _field('Phone Number', _phoneCtrl,
            enabled: !_saving, keyboardType: TextInputType.phone),

        const SizedBox(height: 8),

        DropdownButtonFormField<String>(
          initialValue: _role,
          decoration: InputDecoration(
            labelText: 'Role',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: const [
            DropdownMenuItem(value: 'admin', child: Text('Admin')),
            DropdownMenuItem(value: 'staff', child: Text('Staff')),
          ],
          onChanged:
              _saving ? null : (v) => setState(() => _role = v ?? 'staff'),
        ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2AA39A),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'SAVING...' : 'SAVE CHANGES',
                style: const TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    required bool enabled,
    bool lockIcon = false,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: ctrl,
        enabled: enabled,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: lockIcon
              ? const Icon(Icons.lock)
              : (enabled ? const Icon(Icons.edit) : null),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
