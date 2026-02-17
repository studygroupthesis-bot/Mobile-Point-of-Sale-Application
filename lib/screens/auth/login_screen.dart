import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widget/custom_text_field.dart';
import 'register_screen.dart';
import '../../app/app.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      if (!mounted) return;
      setState(() => loading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (c) => const PopPayApp()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Login failed")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F6),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 60),

            const Text(
              "Log In",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 20),

            /// LOGO
            Image.asset("assets/logo&name.png", height: 140),

            const SizedBox(height: 30),

            /// BOTTOM PANEL (OVERLAPPING)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF055A5B),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(40, 40, 40, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// EMAIL
                  const Text(
                    "Email",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: email,
                    label: "email",
                    hintText: "example@gmail.com",
                    icon: Icons.email,
                  ),

                  const SizedBox(height: 18),

                  /// PASSWORD
                  const Text("Password", style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: password,
                    label: "password",
                    hintText: "••••••••",
                    icon: Icons.lock,
                    isPassword: true,
                  ),

                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  /// LOGIN BUTTON
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
                        onPressed: loading ? null : login,
                        child: loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                "Log In",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF000000),
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// ---- OR SEPARATOR ----
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white54)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text("OR", style: TextStyle(color: Colors.white)),
                      ),
                      Expanded(child: Divider(color: Colors.white54)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  /// GOOGLE SIGN-IN BUTTON
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        // You can add Google sign-in here later
                      },
                      child: Image.asset(
                        "assets/google.png",
                        height: 45,
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  /// REGISTER LINK
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => const RegisterScreen()),
                      ),
                      child: const Text(
                        "Don't have an account? Register here!",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
