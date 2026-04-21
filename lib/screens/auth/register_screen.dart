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

  bool _hasMinLength(String value) => value.length >= 8;
  bool _hasMaxLength(String value) => value.length <= 20;
  bool _hasUppercase(String value) => RegExp(r'[A-Z]').hasMatch(value);
  bool _hasLowercase(String value) => RegExp(r'[a-z]').hasMatch(value);
  bool _hasNumber(String value) => RegExp(r'[0-9]').hasMatch(value);
  bool _hasSpecialChar(String value) =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_+=\-\\/]').hasMatch(value);

  bool _hasLettersNumbersAndSpecial(String value) {
    return _hasLowercase(value) &&
        _hasNumber(value) &&
        _hasSpecialChar(value);
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) return "Password is required";

    if (!_hasMinLength(value) || !_hasMaxLength(value)) {
      return "Password must be 8 to 20 characters";
    }

    if (!_hasUppercase(value)) {
      return "Add at least one uppercase letter";
    }

    if (!_hasLettersNumbersAndSpecial(value)) {
      return "Use letters, numbers, and special characters";
    }

    return null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _ruleItem(String text, bool passed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check,
              size: 16,
              color: passed ? const Color(0xFF11C98D) : Colors.grey,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: passed ? const Color(0xFF11C98D) : Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordGuide() {
    final value = password.text.trim();

    final lengthPassed = _hasMinLength(value) && _hasMaxLength(value);
    final mixPassed =
        _hasLettersNumbersAndSpecial(value) && _hasUppercase(value);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your password must have:",
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _ruleItem("8 to 20 characters", lengthPassed),
          _ruleItem("Letters, numbers, and special characters", mixPassed),
        ],
      ),
    );
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
        _showPasswordGuide = true;
        _passwordError = passwordError;
      });
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
                              CustomTextField(
                                controller: password,
                                label: "Password",
                                hintText: "••••••••",
                                icon: Icons.lock,
                                isPassword: true,
                                errorText: password.text.trim().isNotEmpty
                                    ? _passwordError
                                    : null,
                                onChanged: (value) {
                                  setState(() {
                                    _showPasswordGuide = value.isNotEmpty;
                                    _passwordError = _validatePassword(value);
                                  });
                                },
                              ),
                              if (_showPasswordGuide) _passwordGuide(),
                              SizedBox(height: fieldGap),
                              _label("Confirm Password"),
                              CustomTextField(
                                controller: confirm,
                                label: "Confirm Password",
                                hintText: "••••••••",
                                icon: Icons.lock,
                                isPassword: true,
                                errorText: confirm.text.trim().isNotEmpty &&
                                        confirm.text.trim() !=
                                            password.text.trim()
                                    ? "Passwords do not match"
                                    : null,
                                onChanged: (_) {
                                  setState(() {});
                                },
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