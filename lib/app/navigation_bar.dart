import 'package:flutter/material.dart';

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
                      color: Colors.black.withValues(alpha: 0.22),
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
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 30,
                      color: const Color(0xFF0B7E7B),
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