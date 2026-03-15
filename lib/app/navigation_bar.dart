import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const CustomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 110,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              left: 28,
              right: 28,
              bottom: 10,
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF052C54),
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _navIcon(0, Icons.home_outlined),
                    _navIcon(1, Icons.receipt_long_outlined),
                    const SizedBox(width: 54),
                    _navIcon(3, Icons.inventory_2_outlined),
                    _navIcon(4, Icons.person_outline),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 8,
              child: GestureDetector(
                onTap: () => onTabSelected(2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: currentIndex == 2
                          ? const Color(0xFF76D9D0)
                          : Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _StoreLogoOrIcon(
                      selected: currentIndex == 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(int index, IconData icon) {
    final selected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTabSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? Colors.white : Colors.transparent,
        ),
        child: Icon(
          icon,
          size: 24,
          color: selected ? const Color(0xFF0B7E7B) : Colors.white,
        ),
      ),
    );
  }
}

class _StoreLogoOrIcon extends StatelessWidget {
  final bool selected;

  const _StoreLogoOrIcon({required this.selected});

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
    return Center(
      child: Icon(
        Icons.qr_code_scanner_rounded,
        size: 30,
        color: selected ? const Color(0xFF0B7E7B) : const Color(0xFF0B7E7B),
      ),
    );
  }
}