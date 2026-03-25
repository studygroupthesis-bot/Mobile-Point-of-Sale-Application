import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/dashboard/dashboard_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/inventory/staff_inventory_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/sales/sales_screen.dart';
import '../screens/transaction/transaction_screen.dart' as txn;
import 'navigation_bar.dart';

class PopPayApp extends StatefulWidget {
  const PopPayApp({super.key});

  @override
  State<PopPayApp> createState() => _PopPayAppState();
}

class _PopPayAppState extends State<PopPayApp> {
  int currentIndex = 0;

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
      return const AppScreenShell(
        child: _StateMessageView(
          message: 'No logged-in user found.',
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppScreenShell(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return AppScreenShell(
            child: _StateMessageView(
              message: 'Failed to load user profile: ${snapshot.error}',
            ),
          );
        }

        final userData = snapshot.data?.data();

        if (userData == null) {
          return const AppScreenShell(
            child: _StateMessageView(
              message: 'User profile not found.',
            ),
          );
        }

        final role = (userData['role'] as String?)?.toLowerCase() ?? '';
        final isActive = userData['isActive'] as bool? ?? true;
        final storeId = (userData['storeId'] as String?)?.trim();
        final permissions =
            (userData['permissions'] as Map<String, dynamic>?) ?? {};

        if (!isActive) {
          return const AppScreenShell(
            child: _StateMessageView(
              message: 'This account is inactive.',
            ),
          );
        }

        if (role != 'admin' && role != 'staff') {
          return const AppScreenShell(
            child: _StateMessageView(
              message: 'Invalid user role.',
            ),
          );
        }

        if (storeId == null || storeId.isEmpty) {
          return const AppScreenShell(
            child: _StateMessageView(
              message: 'No store assigned to this account.',
            ),
          );
        }

        final isAdmin = role == 'admin';

        final canViewDashboard = isAdmin;
        final canViewHistory = isAdmin ||
            _permissionValue(
              permissions,
              ['viewTransactions', 'viewTransactionHistory'],
            );

        final canUseInventory = isAdmin ||
            _permissionValue(
              permissions,
              ['viewInventory', 'addStock', 'reduceStock', 'pullOutStock'],
            );

        final canUseTransaction = isAdmin ||
            _permissionValue(
              permissions,
              ['processSales', 'editCart'],
            );

        final screens = <Widget>[
          canViewDashboard
              ? DashboardScreen(
                  onNavigateToTab: _onTabSelected,
                )
              : const AccessDeniedScreen(
                  title: 'Dashboard Restricted',
                  message: 'Your account does not have access to the dashboard.',
                ),
          canViewHistory
              ? const SalesScreen()
              : const AccessDeniedScreen(
                  title: 'History Restricted',
                  message:
                      'Your account does not have access to transaction history.',
                ),
          canUseTransaction
              ? txn.TransactionScreen(
                  isActive: currentIndex == 2,
                )
              : const AccessDeniedScreen(
                  title: 'Sales Restricted',
                  message: 'Your account does not have access to sales.',
                ),
          canUseInventory
              ? (isAdmin
                  ? const InventoryScreen()
                  : const StaffInventoryScreen())
              : const AccessDeniedScreen(
                  title: 'Inventory Restricted',
                  message: 'Your account does not have access to inventory.',
                ),
          const ProfileScreen(),
        ];

        return AppScreenShell(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 96),
                  child: IndexedStack(
                    index: currentIndex,
                    children: screens,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: CustomNavBar(
                      currentIndex: currentIndex,
                      onTabSelected: _onTabSelected,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AppScreenShell extends StatelessWidget {
  final Widget child;

  const AppScreenShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF1F4F4),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AppBackground(),
          SafeArea(
            bottom: false,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _AppBackground extends StatelessWidget {
  const _AppBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: const [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFF1F4F4),
          ),
        ),
        Positioned(
          top: -110,
          left: -110,
          child: _BackgroundGlow(size: 260),
        ),
        Positioned(
          bottom: -130,
          right: -110,
          child: _BackgroundGlow(size: 280),
        ),
      ],
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  final double size;

  const _BackgroundGlow({
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xBFAEE8DF),
          ),
        ),
      ),
    );
  }
}

class _StateMessageView extends StatelessWidget {
  final String message;

  const _StateMessageView({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
    return Center(
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
    );
  }
}