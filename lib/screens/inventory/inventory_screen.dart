import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'create_item_screen.dart';
import 'edit_item_screen.dart';
import 'stock_logs_screen.dart';
import 'inventory_overview_screen.dart';
import 'product_batch_selector_screen.dart';

class InventoryScreen extends StatefulWidget {
  final bool isAdmin;

  const InventoryScreen({
    super.key,
    this.isAdmin = true,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  late final Future<Map<String, String>> _storeAccessFuture;

  @override
  void initState() {
    super.initState();
    _storeAccessFuture = _getStoreAccess();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _getStoreAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Not logged in.");
    }

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userSnap.data();
    final storeId = userData?['storeId'] as String?;

    if (storeId == null || storeId.isEmpty) {
      throw Exception(
        "Missing storeId in users/${user.uid}. Add storeId to the user profile.",
      );
    }

    final storeSnap = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .get();

    final storeData = storeSnap.data();
    final storeName =
        (storeData?['business_name'] ?? 'Store').toString().trim();

    return {
      'storeId': storeId,
      'storeName': storeName,
    };
  }

  void _openStockLogs(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StockLogsScreen()),
    );
  }

  void _openInventoryOverview(
    BuildContext context, {
    required String storeId,
    required String storeName,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryOverviewScreen(
          storeId: storeId,
          storeName: storeName,
          isAdmin: widget.isAdmin,
        ),
      ),
    );
  }

  void _openBatchSelector(
    BuildContext context, {
    required String storeId,
    required String storeName,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductBatchSelectorScreen(
          storeId: storeId,
          storeName: storeName,
        ),
      ),
    );
  }

  String _normalizeCategory(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return 'Uncategorized';
    return text;
  }

  Map<String, dynamic>? _previewDataForCategory(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String category,
  ) {
    for (final doc in docs) {
      final data = doc.data();
      if (_normalizeCategory(data['category']) == category) {
        return data;
      }
    }
    return null;
  }

  Widget _buildLoadingScaffold() {
    return const Scaffold(
      backgroundColor: Color(0xFFD78383),
      body: SafeArea(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildMessageScaffold(String message) {
    return Scaffold(
      backgroundColor: const Color(0xFFD78383),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _buildMessageScaffold("Please login first.");
    }

    return FutureBuilder<Map<String, String>>(
      future: _storeAccessFuture,
      builder: (context, storeSnap) {
        if (storeSnap.connectionState == ConnectionState.waiting) {
          return _buildLoadingScaffold();
        }

        if (storeSnap.hasError) {
          return _buildMessageScaffold(
            "Store access error:\n${storeSnap.error}",
          );
        }

        final storeId = storeSnap.data!['storeId']!;
        final storeName = storeSnap.data!['storeName']!;

        return Scaffold(
          backgroundColor: const Color(0xFFD78383),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6E6E6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('stores')
                          .doc(storeId)
                          .collection('items')
                          .orderBy('created_at', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              "Firestore error:\n${snapshot.error}",
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        final allDocs = snapshot.data?.docs ?? [];

                        final fetchedCategories = allDocs
                            .map((doc) =>
                                _normalizeCategory(doc.data()['category']))
                            .toSet()
                            .toList()
                          ..sort();

                        final categories = ['All', ...fetchedCategories];

                        final query =
                            _searchController.text.trim().toLowerCase();

                        final filteredDocs = allDocs.where((doc) {
                          final data = doc.data();
                          final name =
                              (data['name'] ?? '').toString().toLowerCase();
                          final category = _normalizeCategory(data['category']);

                          final matchCategory = _selectedCategory == 'All'
                              ? true
                              : category == _selectedCategory;

                          final matchSearch =
                              query.isEmpty || name.contains(query);

                          return matchCategory && matchSearch;
                        }).toList();

                        final Map<
                            String,
                            List<
                                QueryDocumentSnapshot<
                                    Map<String, dynamic>>>> grouped = {};

                        for (final doc in filteredDocs) {
                          final category =
                              _normalizeCategory(doc.data()['category']);
                          grouped.putIfAbsent(category, () => []).add(doc);
                        }

                        final sectionNames = _selectedCategory == 'All'
                            ? fetchedCategories
                                .where((c) => grouped[c]?.isNotEmpty ?? false)
                                .toList()
                            : (grouped[_selectedCategory]?.isNotEmpty ?? false)
                                ? [_selectedCategory]
                                : <String>[];

                        return Column(
                          children: [
                            _InventoryHeader(
                              storeName: storeName,
                              isAdmin: widget.isAdmin,
                              onMenuSelected: (value) {
                                if (value == 'stock_logs') {
                                  _openStockLogs(context);
                                } else if (value == 'inventory_overview') {
                                  _openInventoryOverview(
                                    context,
                                    storeId: storeId,
                                    storeName: storeName,
                                  );
                                } else if (value == 'batch_details') {
                                  _openBatchSelector(
                                    context,
                                    storeId: storeId,
                                    storeName: storeName,
                                  );
                                } else if (value == 'create_item') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const CreateItemScreen(),
                                    ),
                                  );
                                } else if (value == 'edit_hint') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Tap an item card to edit"),
                                    ),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.70),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText: "Search",
                                  prefixIcon: Icon(Icons.search, size: 20),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 95,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: categories.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final category = categories[index];
                                  final isSelected =
                                      _selectedCategory == category;

                                  return _CategoryTile(
                                    label: category,
                                    isSelected: isSelected,
                                    previewData: category == 'All'
                                        ? null
                                        : _previewDataForCategory(
                                            allDocs,
                                            category,
                                          ),
                                    onTap: () {
                                      setState(() {
                                        _selectedCategory = category;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: sectionNames.isEmpty
                                  ? Center(
                                      child: Text(
                                        allDocs.isEmpty
                                            ? "No items yet"
                                            : "No items found",
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          for (final section
                                              in sectionNames) ...[
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 6,
                                                bottom: 8,
                                              ),
                                              child: Text(
                                                section,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                            GridView.builder(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              itemCount:
                                                  grouped[section]!.length,
                                              gridDelegate:
                                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 2,
                                                crossAxisSpacing: 10,
                                                mainAxisSpacing: 10,
                                                mainAxisExtent: 145,
                                              ),
                                              itemBuilder: (context, index) {
                                                final doc =
                                                    grouped[section]![index];
                                                return InventoryCard(
                                                  itemId: doc.id,
                                                  itemData: doc.data(),
                                                  isAdmin: widget.isAdmin,
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          if (widget.isAdmin) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                _BottomActionButton(
                                                  text: 'Create Item',
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            const CreateItemScreen(),
                                                      ),
                                                    );
                                                  },
                                                ),
                                                _BottomActionButton(
                                                  text: 'Edit Item',
                                                  onTap: () {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          "Tap an item card to edit",
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InventoryHeader extends StatelessWidget {
  final String storeName;
  final bool isAdmin;
  final ValueChanged<String> onMenuSelected;

  const _InventoryHeader({
    required this.storeName,
    required this.isAdmin,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.shopping_bag_rounded,
            color: Color(0xFFD84C9A),
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            storeName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF153A39),
            ),
          ),
        ),
        PopupMenuButton<String>(
          color: Colors.white,
          icon: const Icon(Icons.menu_rounded, color: Colors.black87),
          onSelected: onMenuSelected,
          itemBuilder: (context) => [
            if (isAdmin)
              const PopupMenuItem(
                value: 'stock_logs',
                child: Text('Stock Logs'),
              ),
            if (isAdmin)
              const PopupMenuItem(
                value: 'create_item',
                child: Text('Create Item'),
              ),
            if (isAdmin)
              const PopupMenuItem(
                value: 'edit_hint',
                child: Text('Edit Item'),
              ),
            if (isAdmin)
              const PopupMenuItem(
                value: 'inventory_overview',
                child: Text('Inventory Overview'),
              ),
            if (isAdmin)
              const PopupMenuItem(
                value: 'batch_details',
                child: Text('Batch Details'),
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Map<String, dynamic>? previewData;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.previewData,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isSelected ? const Color(0xFF72B9B0) : const Color(0xFFCFE7E3);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: label == 'All'
                  ? const Icon(
                      Icons.grid_view_rounded,
                      color: Colors.white,
                      size: 28,
                    )
                  : _MiniPreview(previewData: previewData),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPreview extends StatelessWidget {
  final Map<String, dynamic>? previewData;

  const _MiniPreview({this.previewData});

  @override
  Widget build(BuildContext context) {
    final repType = previewData?['representationType'] as String?;
    final colorValue = previewData?['colorValue'];
    final imageUrl = previewData?['imageUrl'] as String?;

    if (repType == 'image' && imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.fastfood_rounded),
        ),
      );
    }

    if (repType == 'color' && colorValue != null) {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Color(colorValue),
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return const Icon(Icons.fastfood_rounded, size: 26);
  }
}

class _BottomActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _BottomActionButton({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 34,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF59B8AA),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: EdgeInsets.zero,
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class InventoryCard extends StatelessWidget {
  final String itemId;
  final Map<String, dynamic> itemData;
  final bool isAdmin;

  const InventoryCard({
    super.key,
    required this.itemId,
    required this.itemData,
    required this.isAdmin,
  });

  String _priceText(dynamic value) {
    if (value is int) return '₱ $value';
    if (value is double) {
      return value == value.toInt()
          ? '₱ ${value.toInt()}'
          : '₱ ${value.toStringAsFixed(2)}';
    }
    return '₱ ${value ?? 0}';
  }

  int _stockValue(Map<String, dynamic> data) {
    final stock = data['stockQty'] ?? data['stock'] ?? data['quantity'] ?? 0;
    if (stock is int) return stock;
    return int.tryParse(stock.toString()) ?? 0;
  }

  Widget _leadingPreview() {
    final repType = itemData['representationType'] as String?;
    final colorValue = itemData['colorValue'];
    final imageUrl = itemData['imageUrl'] as String?;

    if (repType == 'image' && imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: 58,
          height: 58,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image_not_supported),
          ),
        ),
      );
    }

    if (repType == 'color' && colorValue != null) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Color(colorValue),
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.inventory_2_outlined),
    );
  }

  void _openEdit(BuildContext context) {
    if (!isAdmin) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditItemScreen(
          itemId: itemId,
          itemData: itemData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (itemData['name'] ?? 'No name').toString();
    final price = _priceText(itemData['price']);
    final stock = _stockValue(itemData);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: isAdmin ? () => _openEdit(context) : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFD8F0EC),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (isAdmin)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _openEdit(context),
                  child: const Icon(
                    Icons.edit_square,
                    color: Colors.red,
                    size: 14,
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(child: _leadingPreview()),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF5BBBB0),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$stock',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
