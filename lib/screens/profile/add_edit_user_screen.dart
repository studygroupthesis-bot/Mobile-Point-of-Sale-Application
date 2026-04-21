import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../firebase/store_staff_services.dart';

class AddEditUserScreen extends StatefulWidget {
  final String storeId;
  final String? staffUid;

  const AddEditUserScreen({
    super.key,
    required this.storeId,
    this.staffUid,
  });

  @override
  State<AddEditUserScreen> createState() => _AddEditUserScreenState();
}

class _AddEditUserScreenState extends State<AddEditUserScreen> {
  final _svc = StoreStaffService();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _role = 'staff';
  bool _saving = false;
  bool _initialized = false;

  bool _isActive = true;
  bool _mustChangePassword = true;

  bool _viewInventory = true;
  bool _addStock = true;
  bool _reduceStock = true;
  bool _pullOutStock = true;

  bool _processSales = true;
  bool _editCart = true;

  bool _viewTransactions = true;
  bool _viewReceipts = true;

  bool _viewProfile = true;

  bool get isEdit => widget.staffUid != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _staffStream() {
    if (!isEdit) return null;
    return FirebaseFirestore.instance
        .collection('stores')
        .doc(widget.storeId)
        .collection('staff')
        .doc(widget.staffUid!)
        .snapshots();
  }

  void _loadPermissions(Map<String, dynamic> data) {
    final perms = (data['permissions'] as Map<String, dynamic>?) ?? {};

    final oldInventory = perms['inventoryAccess'];
    final oldSales = perms['salesAccess'];
    final oldTransactions = perms['transactionHistoryAccess'];
    final oldReceipts = perms['receiptAccess'];
    final oldProfile = perms['profileAccess'];

    _viewInventory = perms['viewInventory'] ?? oldInventory ?? true;
    _addStock = perms['addStock'] ?? oldInventory ?? true;
    _reduceStock = perms['reduceStock'] ?? oldInventory ?? true;
    _pullOutStock = perms['pullOutStock'] ?? oldInventory ?? true;

    _processSales = perms['processSales'] ?? oldSales ?? true;
    _editCart = perms['editCart'] ?? oldSales ?? true;

    _viewTransactions = perms['viewTransactions'] ?? oldTransactions ?? true;
    _viewReceipts = perms['viewReceipts'] ?? oldReceipts ?? true;

    _viewProfile = perms['viewProfile'] ?? oldProfile ?? true;
  }

  Map<String, dynamic> _buildPermissions() {
    if (_role == 'admin') {
      return {
        'viewInventory': true,
        'addStock': true,
        'reduceStock': true,
        'pullOutStock': true,
        'processSales': true,
        'editCart': true,
        'viewTransactions': true,
        'viewReceipts': true,
        'viewProfile': true,
      };
    }

    return {
      'viewInventory': _viewInventory,
      'addStock': _addStock,
      'reduceStock': _reduceStock,
      'pullOutStock': _pullOutStock,
      'processSales': _processSales,
      'editCart': _editCart,
      'viewTransactions': _viewTransactions,
      'viewReceipts': _viewReceipts,
      'viewProfile': _viewProfile,
    };
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Add at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Add at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Add at least one number';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_+=\-\\/]').hasMatch(value)) {
      return 'Add at least one special character';
    }
    return null;
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

    if (!isEdit && email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email is required')),
      );
      return;
    }

    if (!isEdit) {
      final passwordError = _validatePassword(pass);
      if (passwordError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(passwordError)),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      if (isEdit) {
        await _svc.updateMember(
          storeId: widget.storeId,
          uid: widget.staffUid!,
          name: name,
          phone: phone,
          role: _role,
          permissions: permissions,
          isActive: _isActive,
          mustChangePassword: _mustChangePassword,
        );
      } else {
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
        uid: widget.staffUid!,
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
                  stream: _staffStream(),
                  builder: (context, snap) {
                    final data = snap.data?.data() ?? {};

                    if (!_initialized && snap.hasData) {
                      _nameCtrl.text = (data['name'] as String?) ?? '';
                      _emailCtrl.text = (data['email'] as String?) ?? '';
                      _phoneCtrl.text = (data['phone'] as String?) ?? '';
                      _role = (data['role'] as String?) ?? 'staff';
                      _isActive = (data['isActive'] as bool?) ?? true;
                      _mustChangePassword =
                          (data['mustChangePassword'] as bool?) ?? false;
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
          const SizedBox(height: 12),
          SwitchListTile(
            value: _isActive,
            onChanged: _saving
                ? null
                : (v) {
                    setState(() => _isActive = v);
                  },
            title: const Text('Active Account'),
            subtitle: const Text('Turn off to block login access'),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: _mustChangePassword,
            onChanged: _saving
                ? null
                : (v) {
                    setState(() => _mustChangePassword = v);
                  },
            title: const Text('Force Password Change'),
            subtitle: const Text('Require password update on next login'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          if (_role == 'staff') ...[
            const Text(
              'Permissions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Inventory',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            _permTile(
              title: 'View Inventory',
              value: _viewInventory,
              onChanged: (v) => setState(() => _viewInventory = v),
            ),
            _permTile(
              title: 'Add Stock',
              value: _addStock,
              onChanged: (v) => setState(() => _addStock = v),
            ),
            _permTile(
              title: 'Reduce Stock',
              value: _reduceStock,
              onChanged: (v) => setState(() => _reduceStock = v),
            ),
            _permTile(
              title: 'Pull Out Stock',
              value: _pullOutStock,
              onChanged: (v) => setState(() => _pullOutStock = v),
            ),
            const SizedBox(height: 10),
            const Text(
              'Sales',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            _permTile(
              title: 'Process Sales',
              value: _processSales,
              onChanged: (v) => setState(() => _processSales = v),
            ),
            _permTile(
              title: 'Edit Cart',
              value: _editCart,
              onChanged: (v) => setState(() => _editCart = v),
            ),
            const SizedBox(height: 10),
            const Text(
              'Records',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            _permTile(
              title: 'View Transactions',
              value: _viewTransactions,
              onChanged: (v) => setState(() => _viewTransactions = v),
            ),
            _permTile(
              title: 'View Receipts',
              value: _viewReceipts,
              onChanged: (v) => setState(() => _viewReceipts = v),
            ),
            const SizedBox(height: 10),
            const Text(
              'Account',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            _permTile(
              title: 'View Profile',
              value: _viewProfile,
              onChanged: (v) => setState(() => _viewProfile = v),
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
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Transform.scale(
            scale: 0.88,
            child: Checkbox(
              value: value,
              onChanged: _saving ? null : (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(
                horizontal: -4,
                vertical: -4,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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