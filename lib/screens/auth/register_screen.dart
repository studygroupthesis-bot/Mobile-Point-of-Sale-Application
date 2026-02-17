import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'widget/custom_text_field.dart';
import 'login_screen.dart';
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
    // ✅ Validation order (clear for users)
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

      // ✅ Create store + link owner user -> storeId
      await StoreService().createStoreForOwner(
        ownerUid: cred.user!.uid,
        email: email.text.trim(),
        ownerName: name.text.trim(), // ✅ IMPORTANT: user name
        businessName: business.text.trim(),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Registration failed")),
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
        bottom: false, // ✅ prevents bottom overflow
        child: Column(
          children: [
            const SizedBox(height: 24),

            const Text(
              "Register",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 10),
            Image.asset("assets/logo&name.png", height: 140),

            /// GREEN PANEL
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
                padding: const EdgeInsets.fromLTRB(40, 28, 40, 24),
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

                    const SizedBox(height: 8),
                    _label("Email"),
                    CustomTextField(
                      controller: email,
                      label: "Email",
                      hintText: "example@gmail.com",
                      icon: Icons.email,
                    ),

                    const SizedBox(height: 8),
                    _label("Password"),
                    CustomTextField(
                      controller: password,
                      label: "Password",
                      hintText: "••••••••",
                      icon: Icons.lock,
                      isPassword: true,
                    ),

                    const SizedBox(height: 8),
                    _label("Confirm Password"),
                    CustomTextField(
                      controller: confirm,
                      label: "Confirm Password",
                      hintText: "••••••••",
                      icon: Icons.lock,
                      isPassword: true,
                    ),

                    const SizedBox(height: 8),
                    _label("Business Name"),
                    CustomTextField(
                      controller: business,
                      label: "Business Name",
                      hintText: "example business name",
                      icon: Icons.business_center,
                    ),

                    const SizedBox(height: 14),

                    /// SMALL CENTER BUTTON
                    Center(
                      child: SizedBox(
                        width: 146,
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
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          "Already have an account? Login here!",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
