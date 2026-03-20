import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/dashboard/dashboard_screen.dart';
import '../screens/sales/transaction_history.dart';
import '../screens/transaction/transaction_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/inventory/staff_inventory_screen.dart';
import '../screens/profile/profile_screen.dart';

import 'navigation_bar.dart';

class PopPayApp extends StatefulWidget {
  const PopPayApp({super.key});

  @override
  State<PopPayApp> createState() => _PopPayAppState();
}

class _PopPayAppState extends State<PopPayApp> {
  int currentIndex = 2;

  void _onTabSelected(int index) {
    setState(() => currentIndex = index);
  }

  bool _permissionValue(
    Map<String, dynamic> permissions,
    List<String> keys, {
    bool defaultValue = false,
  }) {
    for (final key in keys) {
      final value = permissions[key];
      if (value is bool) return value;
    }
    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('No logged-in user found.')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Failed to load user profile: ${snapshot.error}'),
            ),
          );
        }

        final userData = snapshot.data?.data();

        if (userData == null) {
          return const Scaffold(
            body: Center(child: Text('User profile not found.')),
          );
        }

        final role = (userData['role'] as String?)?.toLowerCase() ?? '';
        final isActive = userData['isActive'] as bool? ?? true;
        final storeId = userData['storeId'] as String?;
        final permissions =
            (userData['permissions'] as Map<String, dynamic>?) ?? {};

        if (!isActive) {
          return const Scaffold(
            body: Center(child: Text('This account is inactive.')),
          );
        }

        if (role != 'admin' && role != 'staff') {
          return const Scaffold(
            body: Center(child: Text('Invalid user role.')),
          );
        }

        if (storeId == null || storeId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('No store assigned to this account.')),
          );
        }

        final isAdmin = role == 'admin';

        final canViewDashboard = isAdmin;
        final canViewHistory = isAdmin ||
            _permissionValue(permissions, [
              'viewTransactions',
              'viewTransactionHistory',
            ]);

        final canUseInventory = isAdmin ||
            _permissionValue(permissions, [
              'viewInventory',
              'addStock',
              'reduceStock',
              'pullOutStock',
            ]);

        final canUseTransaction = isAdmin ||
            _permissionValue(permissions, [
              'processSales',
              'editCart',
            ]);

        final screens = <Widget>[
          canViewDashboard
              ? const DashboardScreen()
              : const AccessDeniedScreen(
                  title: 'Dashboard Restricted',
                  message:
                      'Your account does not have access to the dashboard.',
                ),
          canViewHistory
              ? const TransactionHistory()
              : const AccessDeniedScreen(
                  title: 'History Restricted',
                  message:
                      'Your account does not have access to transaction history.',
                ),
          canUseTransaction
              ? TransactionScreen(isActive: currentIndex == 2)
              : const AccessDeniedScreen(
                  title: 'Sales Restricted',
                  message: 'Your account does not have access to sales.',
                ),
          canUseInventory
             ? (isAdmin
                 ? const InventoryScreen()
                 : StaffInventoryScreen())
             : const AccessDeniedScreen(
                 title: 'Inventory Restricted',
                 message: 'Your account does not have access to inventory.',
               ),
          const ProfileScreen(),
        ];

        return Scaffold(
          extendBody: true,
          body: IndexedStack(
            index: currentIndex,
            children: screens,
          ),
          bottomNavigationBar: CustomNavBar(
            currentIndex: currentIndex,
            onTabSelected: _onTabSelected,
          ),
        );
      },
    );
  }
}

class AccessDeniedScreen extends StatelessWidget {
  final String title;
  final String message;

  const AccessDeniedScreen({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F6),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 72,
                color: Color(0xFF055A5B),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF055A5B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
