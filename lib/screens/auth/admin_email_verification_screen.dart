import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/app.dart';

class AdminEmailVerificationScreen extends StatefulWidget {
  final String uid;
  final String email;

  const AdminEmailVerificationScreen({
    super.key,
    required this.uid,
    required this.email,
  });

  @override
  State<AdminEmailVerificationScreen> createState() =>
      _AdminEmailVerificationScreenState();
}

class _AdminEmailVerificationScreenState
    extends State<AdminEmailVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();

  bool _loading = false;
  bool _resending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      _showMessage('Please enter the verification code.');
      return;
    }

    setState(() => _loading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin_login_codes')
          .doc(widget.uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        _showMessage('No verification code found. Please request a new one.');
        return;
      }

      final data = doc.data()!;
      final savedCode = (data['code'] ?? '').toString();
      final used = (data['used'] as bool?) ?? false;
      final expiresAt = data['expiresAt'] as Timestamp?;

      if (used) {
        _showMessage('This verification code was already used.');
        return;
      }

      if (expiresAt == null || DateTime.now().isAfter(expiresAt.toDate())) {
        _showMessage('This verification code has expired.');
        return;
      }

      if (savedCode != code) {
        _showMessage('Incorrect verification code.');
        return;
      }

      await FirebaseFirestore.instance
          .collection('admin_login_codes')
          .doc(widget.uid)
          .set({
        'used': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PopPayApp()),
        (route) => false,
      );
    } catch (e) {
      _showMessage('Verification failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() => _resending = true);

    try {
      final newCode = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
          .toString();

      await FirebaseFirestore.instance
          .collection('admin_login_codes')
          .doc(widget.uid)
          .set({
        'email': widget.email,
        'code': newCode,
        'used': false,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 5)),
        ),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showMessage(
        'New verification code generated. Connect your email sender next.',
      );
    } catch (e) {
      _showMessage('Failed to resend code: $e');
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F6),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 52,
                      color: Color(0xFF055A5B),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Admin Email Verification',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Enter the verification code sent to:\n${widget.email}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'Verification Code',
                        hintText: 'Enter 6-digit code',
                        counterText: '',
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _verifyCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF309E95),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Verify and Continue',
                                style: TextStyle(color: Colors.black),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _resending ? null : _resendCode,
                      child: Text(
                        _resending ? 'Generating...' : 'Resend Code',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Note: connect your actual email sender next so admins receive the code by email.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}