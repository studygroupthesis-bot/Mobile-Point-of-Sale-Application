import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String oobCode;
  final String? email;

  const ResetPasswordScreen({
    super.key,
    required this.oobCode,
    this.email,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController newPassword = TextEditingController();
  final TextEditingController confirmPassword = TextEditingController();

  bool loading = false;
  bool codeValidating = true;
  bool codeValid = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    validateCode();
  }

  @override
  void dispose() {
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  void showAppSnackBar(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFB3261E) : const Color(0xFF2F2D3A),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> validateCode() async {
    try {
      await AuthService.instance.verifyPasswordResetCode(widget.oobCode);

      if (!mounted) return;
      setState(() {
        codeValid = true;
        codeValidating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        codeValid = false;
        codeValidating = false;
        errorText = 'This reset link is invalid or expired.';
      });
    }
  }

  Future<void> resetPassword() async {
    final pass = newPassword.text.trim();
    final confirm = confirmPassword.text.trim();

    if (pass.isEmpty || confirm.isEmpty) {
      showAppSnackBar('Please complete all fields.', isError: true);
      return;
    }

    if (pass.length < 6) {
      showAppSnackBar(
        'Password must be at least 6 characters.',
        isError: true,
      );
      return;
    }

    if (pass != confirm) {
      showAppSnackBar('Passwords do not match.', isError: true);
      return;
    }

    setState(() => loading = true);

    try {
      await AuthService.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: pass,
      );

      if (!mounted) return;

      showAppSnackBar('Password reset successful.');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      showAppSnackBar(
        'Failed to reset password: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (codeValidating) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!codeValid) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              errorText ?? 'Invalid reset link.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (widget.email != null && widget.email!.trim().isNotEmpty)
                Text(
                  widget.email!,
                  style: const TextStyle(fontSize: 15),
                ),
              const SizedBox(height: 24),
              TextField(
                controller: newPassword,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'New password',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPassword,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Confirm password',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: loading ? null : resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF309E95),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Reset Password',
                          style: TextStyle(color: Colors.black),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}