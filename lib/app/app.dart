import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';

import '../screens/dashboard/dashboard_screen.dart';
import '../screens/sales/transaction_history.dart';
import '../screens/transaction/transaction_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/profile/profile_screen.dart';

import 'navigation_bar.dart';

class PopPayApp extends StatefulWidget {
  const PopPayApp({super.key});

  @override
  State<PopPayApp> createState() => _PopPayAppState();
}

class _PopPayAppState extends State<PopPayApp> {
  int currentIndex = 2; // Start at Transaction screen (center button)

  final List<Widget> screens = const [
    DashboardScreen(), // 0
    TransactionHistory(), // 1
    TransactionScreen(), // 2
    InventoryScreen(), // 3
    ProfileScreen(), // 4
  ];

  void _onTabSelected(int index) {
    setState(() => currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: DevicePreview.appBuilder,
      locale: DevicePreview.locale(context),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: screens[currentIndex],

        // Bottom Navigation
        bottomNavigationBar: CustomNavBar(
          currentIndex: currentIndex,
          onTabSelected: _onTabSelected,
        ),
      ),
    );
  }
}
