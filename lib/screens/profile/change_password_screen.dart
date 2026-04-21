import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChangePasswordScreen extends StatefulWidget {
  final bool isForcedChange;

  const ChangePasswordScreen({
    super.key,
    this.isForcedChange = false,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _newPass = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _newPass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validateNewPassword(String value) {
    if (value.isEmpty) return "New password is required";
    if (value.length < 8) return "Password must be at least 8 characters";
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return "Add at least one uppercase letter";
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return "Add at least one lowercase letter";
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return "Add at least one number";
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_+=\-\\/]').hasMatch(value)) {
      return "Add at least one special character";
    }
    return null;
  }

  Future<void> _updatePassword() async {
    if (_current.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Current password is required")),
      );
      return;
    }

    final newPasswordError = _validateNewPassword(_newPass.text.trim());
    if (newPasswordError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newPasswordError)),
      );
      return;
    }

    if (_newPass.text.trim() != _confirm.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("New passwords do not match")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) return;

    setState(() => _saving = true);

    try {
      final cred = EmailAuthProvider.credential(
        email: email,
        password: _current.text.trim(),
      );
      await user.reauthenticateWithCredential(cred);

      await user.updatePassword(_newPass.text.trim());

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'mustChangePassword': false,
        'passwordLastChangedAt': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final storeId = userDoc.data()?['storeId'] as String?;
      if (storeId != null && storeId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('stores')
            .doc(storeId)
            .collection('staff')
            .doc(user.uid)
            .set({
          'mustChangePassword': false,
          'passwordLastChangedAt': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password updated.")),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !widget.isForcedChange,
      child: Scaffold(
        backgroundColor: const Color(0xFFE7F5F4),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: !widget.isForcedChange,
          leading: widget.isForcedChange
              ? null
              : const BackButton(color: Colors.black),
          title: const Text(
            "Change Password",
            style: TextStyle(color: Colors.black),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isForcedChange) ...[
                  const Text(
                    "You need to change your password before continuing.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _tf("Current Password", _current),
                _tf("New Password", _newPass),
                _tf("Confirm Password", _confirm),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _updatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2AA39A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      _saving ? "UPDATING..." : "Update Password",
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tf(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c,
        obscureText: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}