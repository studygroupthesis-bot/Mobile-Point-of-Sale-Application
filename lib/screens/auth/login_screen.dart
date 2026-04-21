import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'widget/custom_text_field.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';
import 'forgot_password_screen.dart';
import 'admin_email_verification_screen.dart';
import '../../app/app.dart';
import '../../services/auth_service.dart';
import '../profile/change_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();

  bool loading = false;
  bool googleLoading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _goTo(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> login() async {
    if (email.text.trim().isEmpty) {
      _showMessage("Email is required");
      return;
    }

    if (password.text.trim().isEmpty) {
      _showMessage("Password is required");
      return;
    }

    setState(() => loading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      await cred.user?.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showMessage("Login failed. User not found.");
        return;
      }

      if (!user.emailVerified) {
        _goTo(
          VerifyEmailScreen(
            email: user.email ?? email.text.trim(),
          ),
        );
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists || userDoc.data() == null) {
        await FirebaseAuth.instance.signOut();
        _showMessage("User profile not found.");
        return;
      }

      final data = userDoc.data()!;
      final isActive = (data['isActive'] as bool?) ?? true;
      final mustChangePassword =
          (data['mustChangePassword'] as bool?) ?? false;
      final passwordLastChangedAt =
          data['passwordLastChangedAt'] as Timestamp?;
      final role = (data['role'] as String?) ?? '';

      if (!isActive) {
        await FirebaseAuth.instance.signOut();
        _showMessage("Your account is inactive. Please contact admin.");
        return;
      }

      if (role.isEmpty) {
        await FirebaseAuth.instance.signOut();
        _showMessage("User role is missing.");
        return;
      }

      bool passwordExpired = false;
      if (passwordLastChangedAt != null) {
        final lastChanged = passwordLastChangedAt.toDate();
        passwordExpired =
            DateTime.now().difference(lastChanged).inDays >= 90;
      }

      if (mustChangePassword || passwordExpired) {
        _goTo(const ChangePasswordScreen(isForcedChange: true));
        return;
      }

      if (role == 'admin') {
        final code =
            (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
                .toString();

        await FirebaseFirestore.instance
            .collection('admin_login_codes')
            .doc(user.uid)
            .set({
          'email': user.email ?? email.text.trim(),
          'code': code,
          'used': false,
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 5)),
          ),
          'createdAt': FieldValue.serverTimestamp(),
        });

        _goTo(
          AdminEmailVerificationScreen(
            uid: user.uid,
            email: user.email ?? email.text.trim(),
          ),
        );
        return;
      }

      _goTo(const PopPayApp());
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? "Login failed";

      if (e.code == 'user-not-found') {
        message = "No account found for that email.";
      } else if (e.code == 'wrong-password') {
        message = "Incorrect password.";
      } else if (e.code == 'invalid-email') {
        message = "Please enter a valid email address.";
      } else if (e.code == 'invalid-credential') {
        message = "Invalid email or password.";
      }

      _showMessage(message);
    } catch (e) {
      _showMessage("Login failed: $e");
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> signInWithGoogle() async {
    setState(() => googleLoading = true);

    try {
      final cred = await AuthService.instance.signInWithGoogle();
      final user = cred.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'google-user-null',
          message: 'Google sign-in failed.',
        );
      }

      await user.reload();
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw FirebaseAuthException(
          code: 'google-user-null',
          message: 'Google sign-in failed.',
        );
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists || userDoc.data() == null) {
        await FirebaseAuth.instance.signOut();
        _showMessage("User profile not found for this Google account.");
        return;
      }

      final data = userDoc.data()!;
      final isActive = (data['isActive'] as bool?) ?? true;
      final mustChangePassword =
          (data['mustChangePassword'] as bool?) ?? false;
      final passwordLastChangedAt =
          data['passwordLastChangedAt'] as Timestamp?;
      final role = (data['role'] as String?) ?? '';

      if (!isActive) {
        await FirebaseAuth.instance.signOut();
        _showMessage("Your account is inactive. Please contact admin.");
        return;
      }

      if (role.isEmpty) {
        await FirebaseAuth.instance.signOut();
        _showMessage("User role is missing.");
        return;
      }

      bool passwordExpired = false;
      if (passwordLastChangedAt != null) {
        final lastChanged = passwordLastChangedAt.toDate();
        passwordExpired =
            DateTime.now().difference(lastChanged).inDays >= 90;
      }

      if (mustChangePassword || passwordExpired) {
        _goTo(const ChangePasswordScreen(isForcedChange: true));
        return;
      }

      if (role == 'admin') {
        final code =
            (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
                .toString();

        await FirebaseFirestore.instance
            .collection('admin_login_codes')
            .doc(currentUser.uid)
            .set({
          'email': currentUser.email ?? '',
          'code': code,
          'used': false,
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 5)),
          ),
          'createdAt': FieldValue.serverTimestamp(),
        });

        _goTo(
          AdminEmailVerificationScreen(
            uid: currentUser.uid,
            email: currentUser.email ?? '',
          ),
        );
        return;
      }

      _goTo(const PopPayApp());
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? 'Google sign-in failed.';

      if (e.code == 'google-sign-in-cancelled') {
        message = 'Google sign-in was cancelled.';
      } else if (e.code == 'account-exists-with-different-credential') {
        message = 'An account already exists with a different sign-in method.';
      } else if (e.code == 'invalid-credential') {
        message = 'Invalid Google credential.';
      }

      _showMessage(message);
    } catch (e) {
      _showMessage("Google sign-in failed: $e");
    } finally {
      if (mounted) {
        setState(() => googleLoading = false);
      }
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

            final topSpacing = isSmallPhone ? 28.0 : 60.0;
            final logoHeight = isSmallPhone ? 110.0 : 140.0;
            final formHorizontalPadding = isSmallPhone ? 24.0 : 40.0;
            final loginButtonWidth = isSmallPhone ? 130.0 : 146.0;

            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      SizedBox(height: topSpacing),
                      const Text(
                        "Log In",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: isSmallPhone ? 16 : 20),
                      Image.asset(
                        "assets/logo&name.png",
                        height: logoHeight,
                      ),
                      SizedBox(height: isSmallPhone ? 20 : 30),
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
                            40,
                            formHorizontalPadding,
                            MediaQuery.of(context).padding.bottom + 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                              const Text(
                                "Password",
                                style: TextStyle(color: Colors.white),
                              ),
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
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Forgot Password?",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: SizedBox(
                                  width: loginButtonWidth,
                                  height: 32,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF309E95),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(15),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    onPressed: loading ? null : login,
                                    child: loading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
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
                              const Row(
                                children: [
                                  Expanded(
                                    child: Divider(color: Colors.white54),
                                  ),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      "OR",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(color: Colors.white54),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Center(
                                child: GestureDetector(
                                  onTap:
                                      googleLoading ? null : signInWithGoogle,
                                  child: googleLoading
                                      ? const SizedBox(
                                          width: 45,
                                          height: 45,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Image.asset(
                                          "assets/google.png",
                                          height: 45,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 25),
                              Center(
                                child: GestureDetector(
                                  onTap: () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const RegisterScreen(),
                                    ),
                                  ),
                                  child: const Text(
                                    "Don't have an account? Register here!",
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
}