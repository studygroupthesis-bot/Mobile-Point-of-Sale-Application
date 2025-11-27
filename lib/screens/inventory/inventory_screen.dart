import 'package:flutter/material.dart';
import '../../screens/inventory/create_item_screen.dart';

class InventoryScreen extends StatelessWidget {
  final bool isAdmin;

  const InventoryScreen(
      {super.key, this.isAdmin = true}); // default = admin for now

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inventory"),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          // 🔹 Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // 🔹 Category chips list
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _categoryChip("All", isSelected: true),
                _categoryChip("Beverages"),
                _categoryChip("Snacks"),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 🔹 Placeholder inventory list (you will implement later)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _inventoryCard("Lay's Classic", "₱ 50"),
                const SizedBox(height: 10),
                _inventoryCard("Presto Peanut Butter", "₱ 40"),
              ],
            ),
          ),

          // 🔹 Admin buttons
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CreateItemScreen()),
                        );
                      },
                      child: const Text("Create Item"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {},
                      child: const Text("Edit Item"),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? Colors.teal : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _inventoryCard(String name, String price) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            color: Colors.grey.shade300,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(price, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}
