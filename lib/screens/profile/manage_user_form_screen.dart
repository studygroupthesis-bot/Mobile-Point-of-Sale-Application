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

  // Permissions
  bool _inventoryAccess = true;
  bool _salesAccess = true;
  bool _transactionHistoryAccess = true;
  bool _receiptAccess = true;
  bool _profileAccess = true;

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

  void _loadPermissions(Map<String, dynamic> data) {
    final perms = (data['permissions'] as Map<String, dynamic>?) ?? {};

    _inventoryAccess = perms['inventoryAccess'] ?? true;
    _salesAccess = perms['salesAccess'] ?? true;
    _transactionHistoryAccess = perms['transactionHistoryAccess'] ?? true;
    _receiptAccess = perms['receiptAccess'] ?? true;
    _profileAccess = perms['profileAccess'] ?? true;
  }

  Map<String, dynamic> _buildPermissions() {
    if (_role == 'admin') {
      return {
        'inventoryAccess': true,
        'salesAccess': true,
        'transactionHistoryAccess': true,
        'receiptAccess': true,
        'profileAccess': true,
      };
    }

    return {
      'inventoryAccess': _inventoryAccess,
      'salesAccess': _salesAccess,
      'transactionHistoryAccess': _transactionHistoryAccess,
      'receiptAccess': _receiptAccess,
      'profileAccess': _profileAccess,
    };
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final permissions = _buildPermissions();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and Password are required')),
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
          permissions: permissions,
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
          permissions: permissions,
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
      await _svc.deleteMember(
        storeId: widget.storeId,
        uid: widget.memberUid!,
      );
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
        title: Text(
          isEdit ? 'Edit User' : 'Add User',
          style: const TextStyle(color: Colors.black),
        ),
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
                      _loadPermissions(data);
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field('Name', _nameCtrl, enabled: !_saving),
          _field(
            'Email Address',
            _emailCtrl,
            enabled: !lockEmail && !_saving,
            lockIcon: lockEmail,
          ),
          if (!isEdit)
            _field(
              'Password',
              _passCtrl,
              enabled: !_saving,
              obscure: true,
            ),
          _field(
            'Phone Number',
            _phoneCtrl,
            enabled: !_saving,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
            key: ValueKey(_role),
            initialValue: _role,
            decoration: InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
              DropdownMenuItem(value: 'staff', child: Text('Staff')),
            ],
            onChanged: _saving
                ? null
                : (v) {
                    setState(() {
                      _role = v ?? 'staff';
                    });
                  },
          ),

          const SizedBox(height: 16),

          if (_role == 'staff') ...[
            const Text(
              'Permissions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),

            _permTile(
              title: 'Inventory Access',
              value: _inventoryAccess,
              onChanged: (v) => setState(() => _inventoryAccess = v),
            ),
            _permTile(
              title: 'Sales / Add to Cart',
              value: _salesAccess,
              onChanged: (v) => setState(() => _salesAccess = v),
            ),
            _permTile(
              title: 'Transaction History',
              value: _transactionHistoryAccess,
              onChanged: (v) => setState(() => _transactionHistoryAccess = v),
            ),
            _permTile(
              title: 'Receipt Access',
              value: _receiptAccess,
              onChanged: (v) => setState(() => _receiptAccess = v),
            ),
            _permTile(
              title: 'Profile Access',
              value: _profileAccess,
              onChanged: (v) => setState(() => _profileAccess = v),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Admin has full access to all features.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ],

          const SizedBox(height: 20),

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
              child: Text(
                _saving ? 'SAVING...' : 'SAVE CHANGES',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: _saving ? null : (v) => onChanged(v ?? false),
        title: Text(title),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}