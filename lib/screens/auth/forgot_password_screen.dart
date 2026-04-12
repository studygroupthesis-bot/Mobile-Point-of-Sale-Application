import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  bool loading = false;
  bool sent = false;

  @override
  void dispose() {
    emailController.dispose();
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

  bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );
    return emailRegex.hasMatch(email);
  }

  Future<void> sendResetLink() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showAppSnackBar('Please enter your email.', isError: true);
      return;
    }

    if (!isValidEmail(email)) {
      showAppSnackBar('Please enter a valid email address.', isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => loading = true);

    try {
      await AuthService.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      setState(() => sent = true);

      showAppSnackBar('Password reset link sent. Please check your email.');
    } on Exception catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        'Failed to send reset link: ${e.toString()}',
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
                'Forgot Password',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                sent
                    ? 'A reset link has been sent to your email.'
                    : 'Enter your email and we’ll send you a password reset link.',
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => loading ? null : sendResetLink(),
                decoration: InputDecoration(
                  hintText: 'example@gmail.com',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.email),
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
                  onPressed: loading ? null : sendResetLink,
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
                          'Send Reset Link',
                          style: TextStyle(color: Colors.black),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(context),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}