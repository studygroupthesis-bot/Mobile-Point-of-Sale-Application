import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  const CustomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Bottom background bar
        Container(
          height: 70,
          margin: const EdgeInsets.only(top: 25),
          decoration: BoxDecoration(
            color: const Color(0xFF052C54),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navIcon(0, Icons.home_outlined),
              _navIcon(1, Icons.receipt_long_outlined),
              const SizedBox(width: 40),
              _navIcon(3, Icons.inventory_2_outlined),
              _navIcon(4, Icons.person_outline),
            ],
          ),
        ),

        // Floating Transaction Button (NOW shows store logo)
        Positioned(
          top: -10,
          child: GestureDetector(
            onTap: () => onTabSelected(2),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: _StoreLogoOrIcon(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _navIcon(int index, IconData icon) {
    bool selected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTabSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? Colors.white : Colors.transparent,
        ),
        child: Icon(
          icon,
          size: 28,
          color: selected ? Colors.teal : Colors.white,
        ),
      ),
    );
  }
}

class _StoreLogoOrIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return _fallbackIcon();
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, userSnap) {
        final storeId = userSnap.data?.data()?['storeId'] as String?;
        if (storeId == null || storeId.isEmpty) {
          return _fallbackIcon();
        }

        final storeRef =
            FirebaseFirestore.instance.collection('stores').doc(storeId);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: storeRef.snapshots(),
          builder: (context, storeSnap) {
            final logoUrl = storeSnap.data?.data()?['logo_url'] as String?;
            if (logoUrl == null || logoUrl.isEmpty) {
              return _fallbackIcon();
            }

            return Image.network(
              logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackIcon(),
            );
          },
        );
      },
    );
  }

  Widget _fallbackIcon() {
    return const Center(
      child: Icon(
        Icons.qr_code_scanner_rounded,
        size: 32,
        color: Colors.teal,
      ),
    );
  }
}
