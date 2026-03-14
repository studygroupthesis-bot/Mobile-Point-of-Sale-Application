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

  Future<void> register() async {
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name is required")),
      );
      return;
    }

    if (email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email is required")),
      );
      return;
    }

    if (password.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password is required")),
      );
      return;
    }

    if (password.text.trim() != confirm.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    if (business.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Business name is required")),
      );
      return;
    }

    try {
      setState(() => loading = true);

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
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
        email: email.text.trim(),
        ownerName: name.text.trim(),
        businessName: business.text.trim(),
      );

      await user.sendEmailVerification();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(email: email.text.trim()),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong. Try again.")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    business.dispose();
    super.dispose();
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