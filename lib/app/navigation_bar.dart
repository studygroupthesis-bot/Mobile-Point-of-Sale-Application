import 'package:flutter/material.dart';

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
                color: Colors.black.withOpacity(0.25),
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

              const SizedBox(width: 40), // Space under floating button

              _navIcon(3, Icons.inventory_2_outlined),
              _navIcon(4, Icons.person_outline),
            ],
          ),
        ),

        // Floating Transaction Button
        Positioned(
          top: -10,
          child: GestureDetector(
            onTap: () => onTabSelected(2), // CORRECT: Transaction index = 2
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                size: 32,
                color: Colors.teal,
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
