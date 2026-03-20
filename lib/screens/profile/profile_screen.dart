import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'account_settings_screen.dart';
import 'manage_users_screen.dart';
import 'store_settings_screen.dart';
import 'data_sync_screen.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFE7F5F4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(width: 5),
                  Text(
                    "My Business",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StoreHeader(uid: uid),
                    const SizedBox(height: 25),
                    _menuItem(
                      icon: Icons.settings,
                      title: "Account Settings",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccountSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    if (uid != null)
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection("users")
                            .doc(uid)
                            .snapshots(),
                        builder: (context, snap) {
                          final data = snap.data?.data();
                          final role = (data?['role'] as String?) ?? '';
                          final isAdmin = role == 'admin';

                          return Column(
                            children: [
                              if (isAdmin)
                                _menuItem(
                                  icon: Icons.group,
                                  title: "Manage Users",
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ManageUsersScreen(),
                                      ),
                                    );
                                  },
                                ),
                              _menuItem(
                                icon: Icons.store_mall_directory,
                                title: "Store Settings",
                                subtitle: isAdmin
                                    ? "Business, payments, and tax settings"
                                    : "Admin only",
                                enabled: isAdmin,
                                onTap: isAdmin
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const StoreSettingsScreen(),
                                          ),
                                        );
                                      }
                                    : null,
                              ),
                            ],
                          );
                        },
                      )
                    else
                      _menuItem(
                        icon: Icons.store_mall_directory,
                        title: "Store Settings",
                        subtitle: "Admin only",
                        enabled: false,
                        onTap: null,
                      ),
                    _menuItem(
                      icon: Icons.cloud_sync,
                      title: "Data Sync",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DataSyncScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => logout(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2AA39A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "SIGN OUT",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    final color = enabled ? Colors.black : Colors.black38;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, color: color),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: enabled ? Colors.black54 : Colors.black38,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 24, color: color),
          ],
        ),
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  final String? uid;
  const _StoreHeader({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return _headerRow(name: "My Business", logoUrl: null);
    }

    final userRef = FirebaseFirestore.instance.collection("users").doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final storeId = userData?["storeId"] as String?;

        if (storeId == null || storeId.isEmpty) {
          final fallback =
              (userData?["business_name"] as String?) ?? "My Business";
          return _headerRow(name: fallback, logoUrl: null);
        }

        final storeRef =
            FirebaseFirestore.instance.collection("stores").doc(storeId);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: storeRef.snapshots(),
          builder: (context, storeSnap) {
            final storeData = storeSnap.data?.data() ?? {};
            final name =
                (storeData["business_name"] as String?) ?? "My Business";
            final logoUrl = storeData["logo_url"] as String?;
            return _headerRow(name: name, logoUrl: logoUrl);
          },
        );
      },
    );
  }

  Widget _headerRow({required String name, required String? logoUrl}) {
    return Row(
      children: [
        CircleAvatar(
          radius: 27.5,
          backgroundColor: Colors.pink.shade300,
          backgroundImage: (logoUrl != null && logoUrl.isNotEmpty)
              ? NetworkImage(logoUrl)
              : null,
          child: (logoUrl == null || logoUrl.isEmpty)
              ? const Icon(Icons.store, color: Colors.white, size: 30)
              : null,
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
