import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'widget/custom_text_field.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';
import '../../firebase/stores_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final business = TextEditingController();

  bool loading = false;

  bool _showPasswordGuide = false;
  String? _passwordError;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    business.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(value);
  }

  bool _hasUppercase(String value) => RegExp(r'[A-Z]').hasMatch(value);
  bool _hasLowercase(String value) => RegExp(r'[a-z]').hasMatch(value);
  bool _hasNumber(String value) => RegExp(r'[0-9]').hasMatch(value);
  bool _hasSpecialChar(String value) =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_+=\-\\/]').hasMatch(value);
  bool _hasMinLength(String value) => value.length >= 8;

  String? _validatePassword(String value) {
    if (value.isEmpty) return "Password is required";
    if (!_hasMinLength(value)) return "Password must be at least 8 characters";
    if (!_hasUppercase(value)) return "Add at least one uppercase letter";
    if (!_hasLowercase(value)) return "Add at least one lowercase letter";
    if (!_hasNumber(value)) return "Add at least one number";
    if (!_hasSpecialChar(value)) return "Add at least one special character";
    return null;
  }

  Future<void> register() async {
    final fullName = name.text.trim();
    final emailText = email.text.trim();
    final passwordText = password.text.trim();
    final confirmText = confirm.text.trim();
    final businessName = business.text.trim();

    if (fullName.isEmpty) {
      _showMessage("Name is required");
      return;
    }

    if (emailText.isEmpty) {
      _showMessage("Email is required");
      return;
    }

    if (!_isValidEmail(emailText)) {
      _showMessage("Please enter a valid email address");
      return;
    }

    final passwordError = _validatePassword(passwordText);
    if (passwordError != null) {
      setState(() {
        _passwordError = passwordError;
        _showPasswordGuide = true;
      });
      _showMessage(passwordError);
      return;
    }

    if (confirmText.isEmpty) {
      _showMessage("Confirm password is required");
      return;
    }

    if (passwordText != confirmText) {
      _showMessage("Passwords do not match");
      return;
    }

    if (businessName.isEmpty) {
      _showMessage("Business name is required");
      return;
    }

    try {
      setState(() => loading = true);

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailText,
        password: passwordText,
      );

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'User was not created.',
        );
      }

      await StoreService().createStoreForOwner(
        ownerUid: user.uid,
        email: emailText,
        ownerName: fullName,
        businessName: businessName,
      );

      await user.sendEmailVerification();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(email: emailText),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = e.message ?? "Registration failed";

      if (e.code == 'email-already-in-use') {
        message = "That email is already registered.";
      } else if (e.code == 'invalid-email') {
        message = "Please enter a valid email address.";
      } else if (e.code == 'weak-password') {
        message = "Password is too weak.";
      }

      _showMessage(message);
    } catch (e) {
      if (!mounted) return;
      _showMessage("Something went wrong: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildPasswordRule(String text, bool passed) {
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle : Icons.cancel,
          size: 18,
          color: passed ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: passed ? Colors.green.shade700 : Colors.red.shade700,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _passwordGuideCard() {
    final value = password.text.trim();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Password must contain:",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          _buildPasswordRule("At least 8 characters", _hasMinLength(value)),
          const SizedBox(height: 6),
          _buildPasswordRule("One uppercase letter", _hasUppercase(value)),
          const SizedBox(height: 6),
          _buildPasswordRule("One lowercase letter", _hasLowercase(value)),
          const SizedBox(height: 6),
          _buildPasswordRule("One number", _hasNumber(value)),
          const SizedBox(height: 6),
          _buildPasswordRule("One special character", _hasSpecialChar(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F6),
      body: SafeArea(
        top: true,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final isSmallPhone = screenWidth < 360;

            final topSpacing = isSmallPhone ? 20.0 : 28.0;
            final logoHeight = isSmallPhone ? 105.0 : 140.0;
            final formHorizontalPadding = isSmallPhone ? 24.0 : 40.0;
            final fieldGap = isSmallPhone ? 6.0 : 8.0;
            final buttonWidth = isSmallPhone ? 130.0 : 146.0;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      SizedBox(height: topSpacing),
                      const Text(
                        "Register",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: isSmallPhone ? 8 : 10),
                      Image.asset(
                        "assets/logo&name.png",
                        height: logoHeight,
                      ),
                      SizedBox(height: isSmallPhone ? 14 : 18),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Color(0xFF055A5B),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(50),
                              topRight: Radius.circular(50),
                            ),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            formHorizontalPadding,
                            isSmallPhone ? 22 : 28,
                            formHorizontalPadding,
                            MediaQuery.of(context).padding.bottom + 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label("Name"),
                              CustomTextField(
                                controller: name,
                                label: "Name",
                                hintText: "Juan Dela Cruz",
                                icon: Icons.person,
                              ),
                              SizedBox(height: fieldGap),

                              _label("Email"),
                              CustomTextField(
                                controller: email,
                                label: "Email",
                                hintText: "example@gmail.com",
                                icon: Icons.email,
                              ),
                              SizedBox(height: fieldGap),

                              _label("Password"),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _passwordError != null
                                        ? Colors.red
                                        : Colors.transparent,
                                    width: 1.4,
                                  ),
                                ),
                                child: CustomTextField(
                                  controller: password,
                                  label: "Password",
                                  hintText: "••••••••",
                                  icon: Icons.lock,
                                  isPassword: true,
                                  onChanged: (value) {
                                    setState(() {
                                      _showPasswordGuide = value.isNotEmpty;
                                      _passwordError = _validatePassword(value);
                                    });
                                  },
                                ),
                              ),

                              if (_showPasswordGuide) _passwordGuideCard(),

                              if (_passwordError != null &&
                                  password.text.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    _passwordError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),

                              SizedBox(height: fieldGap),

                              _label("Confirm Password"),
                              CustomTextField(
                                controller: confirm,
                                label: "Confirm Password",
                                hintText: "••••••••",
                                icon: Icons.lock,
                                isPassword: true,
                              ),
                              SizedBox(height: fieldGap),

                              _label("Business Name"),
                              CustomTextField(
                                controller: business,
                                label: "Business Name",
                                hintText: "example business name",
                                icon: Icons.business_center,
                              ),
                              SizedBox(height: isSmallPhone ? 12 : 14),

                              Center(
                                child: SizedBox(
                                  width: buttonWidth,
                                  height: 32,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF309E95),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    onPressed: loading ? null : register,
                                    child: loading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            "Register",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: GestureDetector(
                                  onTap: () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                  ),
                                  child: const Text(
                                    "Already have an account? Login here!",
                                    style: TextStyle(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}