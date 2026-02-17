import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../screens/inventory/create_item_screen.dart';
import '../../screens/inventory/edit_item_screen.dart';

class InventoryScreen extends StatelessWidget {
  final bool isAdmin;

  const InventoryScreen({
    super.key,
    this.isAdmin = true,
  });

  Future<String> _requireStoreId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Not logged in.");
    }

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final storeId = snap.data()?['storeId'] as String?;
    if (storeId == null || storeId.isEmpty) {
      throw Exception(
        "Missing storeId in users/${user.uid}. Add storeId to the user profile.",
      );
    }

    return storeId;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login first.")),
      );
    }

    return FutureBuilder<String>(
      future: _requireStoreId(),
      builder: (context, storeSnap) {
        if (storeSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (storeSnap.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                "Store access error:\n${storeSnap.error}",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final storeId = storeSnap.data!;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7F9),
          appBar: AppBar(
            title: const Text("Inventory"),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
          body: Column(
            children: [
              /// 🔍 SEARCH BAR (UI only)
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 15, 30, 10),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        spreadRadius: -1,
                      ),
                    ],
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: "Search...",
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
              ),

              /// 🏷 CATEGORY CHIPS (UI only)
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  children: const [
                    _CategoryChip(label: "All", isSelected: true),
                    _CategoryChip(label: "Beverages"),
                    _CategoryChip(label: "Snacks"),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              /// 📦 INVENTORY LIST (✅ FIXED PATH)
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('stores')
                      .doc(storeId)
                      .collection('items')
                      .orderBy('created_at', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "Firestore error:\n${snapshot.error}",
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "No items yet",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    final items = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final doc = items[index];
                        final data = doc.data();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InventoryCard(
                            itemId: doc.id,
                            itemData: data,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              /// ➕ ADMIN BUTTONS
              if (isAdmin)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateItemScreen(),
                              ),
                            );
                          },
                          child: const Text("Create Item"),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Tap an item to edit"),
                              ),
                            );
                          },
                          child: const Text("Edit Item"),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// =======================
/// CATEGORY CHIP
/// =======================
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _CategoryChip({
    required this.label,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? Colors.teal : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}

/// =======================
/// INVENTORY CARD (HOVER + TAP → EDIT)
/// =======================
class InventoryCard extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> itemData;

  const InventoryCard({
    super.key,
    required this.itemId,
    required this.itemData,
  });

  @override
  State<InventoryCard> createState() => _InventoryCardState();
}

class _InventoryCardState extends State<InventoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.itemData['name'] ?? 'No name';
    final price = "₱ ${widget.itemData['price'] ?? 0}";

    final repType = widget.itemData['representationType'] as String?;
    final colorValue = widget.itemData['colorValue'];
    final imageUrl = widget.itemData['imageUrl'] as String?;

    Widget leadingPreview() {
      // IMAGE
      if (repType == 'image' && imageUrl != null && imageUrl.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            width: 55,
            height: 55,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 55,
              height: 55,
              color: Colors.grey.shade300,
              child: const Icon(Icons.image_not_supported),
            ),
          ),
        );
      }

      // COLOR
      if (repType == 'color' && colorValue != null) {
        return Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            color: Color(colorValue),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }

      // FALLBACK
      return Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.inventory_2_outlined),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditItemScreen(
                itemId: widget.itemId,
                itemData: widget.itemData,
              ),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.teal.withValues(alpha: 0.15)
                : Colors.teal.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered ? Colors.teal : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              leadingPreview(),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(price),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
