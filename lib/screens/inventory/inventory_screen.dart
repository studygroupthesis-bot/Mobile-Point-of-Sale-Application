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
  String _search = '';

  late final Future<_AdminStoreAccess> _storeAccessFuture;

  static const double _floatingPanelHeight = 35;
  static const double _floatingPanelBottomOffset = 30;
  static const double _reservedBottomSpace = 100;

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

  Future<_AdminStoreAccess> _getStoreAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not logged in.');
    }

    final userSnap =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final userData = userSnap.data();
    final storeId = userData?['storeId'] as String?;

    if (storeId == null || storeId.isEmpty) {
      throw Exception(
        'Missing storeId in users/${user.uid}. Add storeId to the user profile.',
      );
    }

    final storeSnap = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .get();

    final storeData = storeSnap.data() ?? <String, dynamic>{};

    final storeName =
        (storeData['business_name'] ?? storeData['storeName'] ?? 'Store')
            .toString()
            .trim();

    final storeLogoUrl = (storeData['logoUrl'] ??
            storeData['storeLogoUrl'] ??
            storeData['logo_url'] ??
            storeData['imageUrl'] ??
            '')
        .toString()
        .trim();

    return _AdminStoreAccess(
      storeId: storeId,
      storeName: storeName.isEmpty ? 'Store' : storeName,
      storeLogoUrl: storeLogoUrl,
    );
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

  String _peso(num value) => '₱${value.toStringAsFixed(2)}';

  Map<String, List<InventoryItem>> _buildSections(List<InventoryItem> items) {
    final Map<String, List<InventoryItem>> grouped = {};

    for (final item in items) {
      final category =
          item.category.trim().isEmpty ? 'Uncategorized' : item.category.trim();
      grouped.putIfAbsent(category, () => []);
      grouped[category]!.add(item);
    }

    for (final entry in grouped.entries) {
      entry.value.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    if (_selectedCategory == 'All') {
      final sortedKeys = grouped.keys.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return {
        for (final key in sortedKeys) key: grouped[key]!,
      };
    }

    final selected = grouped.entries.where(
      (e) => e.key.toLowerCase() == _selectedCategory.toLowerCase(),
    );

    return {
      for (final entry in selected) entry.key: entry.value,
    };
  }

  Widget _buildLoadingScaffold() {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF309E95),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageScaffold(String message) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMenuMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildCategorySection(
    BuildContext context, {
    required String category,
    required List<InventoryItem> items,
  }) {
    final bool showHorizontal = _selectedCategory == 'All';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          if (showHorizontal)
            SizedBox(
              height: 185,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                padding: const EdgeInsets.only(right: 18),
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final item = items[index];

                  return SizedBox(
                    width: 148,
                    child: _AdminItemCard(
                      item: item,
                      peso: _peso,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditItemScreen(
                              itemId: item.id,
                              itemData: item.rawData,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.80,
              ),
              itemBuilder: (context, index) {
                final item = items[index];

                return _AdminItemCard(
                  item: item,
                  peso: _peso,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditItemScreen(
                          itemId: item.id,
                          itemData: item.rawData,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _buildMessageScaffold('Please login first.');
    }

    final safeBottom = MediaQuery.of(context).padding.bottom;

    return FutureBuilder<_AdminStoreAccess>(
      future: _storeAccessFuture,
      builder: (context, storeSnap) {
        if (storeSnap.connectionState == ConnectionState.waiting) {
          return _buildLoadingScaffold();
        }

        if (storeSnap.hasError) {
          return _buildMessageScaffold(
            'Store access error:\n${storeSnap.error}',
          );
        }

        final access = storeSnap.data!;
        final storeId = access.storeId;
        final storeName = access.storeName;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('stores')
                  .doc(storeId)
                  .collection('items')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Firestore error:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF309E95),
                    ),
                  );
                }

                final allItems = snapshot.data!.docs
                    .map((doc) => InventoryItem.fromDoc(doc))
                    .toList();

                final categories = <String>{
                  'All',
                  ...allItems
                      .map(
                        (e) => e.category.trim().isEmpty
                            ? 'Uncategorized'
                            : e.category.trim(),
                      )
                      .where((e) => e.isNotEmpty),
                }.toList()
                  ..sort((a, b) {
                    if (a == 'All') return -1;
                    if (b == 'All') return 1;
                    return a.toLowerCase().compareTo(b.toLowerCase());
                  });

                final searchedItems = allItems.where((item) {
                  if (_search.trim().isEmpty) return true;

                  final q = _search.toLowerCase();
                  return item.name.toLowerCase().contains(q) ||
                      item.category.toLowerCase().contains(q) ||
                      item.barcode.toLowerCase().contains(q);
                }).toList();

                final sectionMap = _buildSections(searchedItems);

                return Stack(
                  children: [
                    Positioned.fill(
                      bottom: _reservedBottomSpace + safeBottom,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _StoreAvatar(
                                  storeName: storeName,
                                  storeLogoUrl: access.storeLogoUrl,
                                  size: 50,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      storeName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                        height: 1.05,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color:
                                        const Color(0xFFFFFFFF).withAlpha(128),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: PopupMenuButton<String>(
                                    tooltip: 'Inventory actions',
                                    color: Colors.white,
                                    padding: EdgeInsets.zero,
                                    onSelected: (value) {
                                      if (value == 'stock_logs') {
                                        _openStockLogs(context);
                                      } else if (value == 'create_item') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const CreateItemScreen(),
                                          ),
                                        );
                                      } else if (value == 'edit_hint') {
                                        _showMenuMessage(
                                          'Tap an item card to edit.',
                                        );
                                      } else if (value ==
                                          'inventory_overview') {
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
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'stock_logs',
                                        child: Text('Stock Logs'),
                                      ),
                                      PopupMenuItem(
                                        value: 'create_item',
                                        child: Text('Create Item'),
                                      ),
                                      PopupMenuItem(
                                        value: 'edit_hint',
                                        child: Text('Edit Item'),
                                      ),
                                      PopupMenuItem(
                                        value: 'inventory_overview',
                                        child: Text('Inventory Overview'),
                                      ),
                                      PopupMenuItem(
                                        value: 'batch_details',
                                        child: Text('Batch Details'),
                                      ),
                                    ],
                                    icon: const Icon(
                                      Icons.menu_rounded,
                                      size: 24,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F8F8),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x18000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) {
                                  setState(() {
                                    _search = value.trim();
                                  });
                                },
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search',
                                  hintStyle: TextStyle(
                                    color: Colors.black.withAlpha(90),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  suffixIcon: const Padding(
                                    padding: EdgeInsets.only(right: 10),
                                    child: Icon(
                                      Icons.search_rounded,
                                      size: 28,
                                      color: Colors.black,
                                    ),
                                  ),
                                  suffixIconConstraints: const BoxConstraints(
                                    minWidth: 42,
                                    minHeight: 42,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Categories',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 92,
                              child: ListView.separated(
                                padding: const EdgeInsets.only(right: 18),
                                scrollDirection: Axis.horizontal,
                                itemCount: categories.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final category = categories[index];
                                  final selected =
                                      _selectedCategory == category;

                                  return _AdminCategoryCard(
                                    category: category,
                                    selected: selected,
                                    items: allItems,
                                    onTap: () {
                                      setState(() {
                                        _selectedCategory = category;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (sectionMap.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 50),
                                child: Center(
                                  child: Text(
                                    'No items found.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...sectionMap.entries.map((entry) {
                                return _buildCategorySection(
                                  context,
                                  category: entry.key,
                                  items: entry.value,
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: _floatingPanelBottomOffset + safeBottom,
                      child: SafeArea(
                        top: false,
                        child: SizedBox(
                          height: _floatingPanelHeight,
                          child: Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const CreateItemScreen(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF309E95),
                                      foregroundColor: Colors.white,
                                      elevation: 6,
                                      shadowColor: const Color(0x22000000),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: const Text(
                                      'Create Item',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      _showMenuMessage(
                                        'Tap an item card to edit.',
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          const Color(0xFF309E95),
                                      side: const BorderSide(
                                        color: Color(0xFF309E95),
                                      ),
                                      backgroundColor:
                                          const Color(0xFFEAF7F4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: const Text(
                                      'Edit Item',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _AdminStoreAccess {
  final String storeId;
  final String storeName;
  final String storeLogoUrl;

  const _AdminStoreAccess({
    required this.storeId,
    required this.storeName,
    required this.storeLogoUrl,
  });
}

class _StoreAvatar extends StatelessWidget {
  final String storeName;
  final String storeLogoUrl;
  final double size;

  const _StoreAvatar({
    required this.storeName,
    required this.storeLogoUrl,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        storeName.trim().isEmpty ? 'S' : storeName.trim()[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: storeLogoUrl.isNotEmpty
            ? Image.network(
                storeLogoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: size * 0.42,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFB11C8E),
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFB11C8E),
                  ),
                ),
              ),
      ),
    );
  }
}

class _AdminCategoryCard extends StatelessWidget {
  final String category;
  final bool selected;
  final List<InventoryItem> items;
  final VoidCallback onTap;

  const _AdminCategoryCard({
    required this.category,
    required this.selected,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF5A9896) : const Color(0xFFB0D8D6);
    final fg = selected ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: category == 'All'
                    ? Icon(
                        Icons.grid_view_rounded,
                        size: 50,
                        color: fg,
                      )
                    : _CategoryThumb(
                        category: category,
                        items: items,
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              category,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.05,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminItemCard extends StatelessWidget {
  final InventoryItem item;
  final String Function(num value) peso;
  final VoidCallback onTap;

  const _AdminItemCard({
    required this.item,
    required this.peso,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stock = item.stockQty ?? 0;
    final hasStock = item.trackStock && item.stockQty != null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFD8E1E5),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF).withAlpha(72),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: _ProductThumb(
                      item: item,
                      size: 60,
                      radius: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  peso(item.price),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                if (hasStock)
                  Text(
                    'Stock: $stock',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF).withAlpha(210),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: Color(0xFF33AAA0),
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

class _ProductThumb extends StatelessWidget {
  final InventoryItem item;
  final double size;
  final double radius;

  const _ProductThumb({
    required this.item,
    required this.size,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    if (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.network(
            item.imageUrl!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _FallbackItemVisual(
              item: item,
              size: size,
              radius: radius,
            ),
          ),
        ),
      );
    }

    return _FallbackItemVisual(
      item: item,
      size: size,
      radius: radius,
    );
  }
}

class _FallbackItemVisual extends StatelessWidget {
  final InventoryItem item;
  final double size;
  final double radius;

  const _FallbackItemVisual({
    required this.item,
    required this.size,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    if (item.representationType == 'color' && item.colorValue != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color(item.colorValue!),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE7ECED),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        color: Colors.black.withAlpha(88),
        size: size * 0.42,
      ),
    );
  }
}

class _CategoryThumb extends StatelessWidget {
  final String category;
  final List<InventoryItem> items;

  const _CategoryThumb({
    required this.category,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    InventoryItem? first;

    for (final item in items) {
      final normalized =
          item.category.trim().isEmpty ? 'Uncategorized' : item.category.trim();

      if (normalized.toLowerCase() == category.toLowerCase()) {
        first = item;
        break;
      }
    }

    if (first == null) {
      return const Icon(
        Icons.category_outlined,
        size: 28,
        color: Colors.black87,
      );
    }

    return _ProductThumb(
      item: first,
      size: 53,
      radius: 8,
    );
  }
}

class InventoryItem {
  final String id;
  final String barcode;
  final String category;
  final int? colorValue;
  final String? imageUrl;
  final String name;
  final double price;
  final String representationType;
  final String soldBy;
  final int? stockQty;
  final bool trackStock;
  final Map<String, dynamic> rawData;

  InventoryItem({
    required this.id,
    required this.barcode,
    required this.category,
    required this.colorValue,
    required this.imageUrl,
    required this.name,
    required this.price,
    required this.representationType,
    required this.soldBy,
    required this.stockQty,
    required this.trackStock,
    required this.rawData,
  });

  factory InventoryItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    double price = 0;
    final rawPrice = data['price'];
    if (rawPrice is int) {
      price = rawPrice.toDouble();
    } else if (rawPrice is double) {
      price = rawPrice;
    } else if (rawPrice is String) {
      price = double.tryParse(rawPrice) ?? 0;
    }

    int? colorValue;
    final rawColor = data['colorValue'];
    if (rawColor is int) {
      colorValue = rawColor;
    } else if (rawColor is num) {
      colorValue = rawColor.toInt();
    }

    int? stockQty;
    final rawStock = data['stockQty'] ?? data['stock'] ?? data['quantity'];
    if (rawStock is int) {
      stockQty = rawStock;
    } else if (rawStock is double) {
      stockQty = rawStock.toInt();
    } else if (rawStock is String) {
      stockQty = int.tryParse(rawStock);
    }

    return InventoryItem(
      id: doc.id,
      barcode: (data['barcode'] ?? '').toString(),
      category: (data['category'] ?? 'Uncategorized').toString(),
      colorValue: colorValue,
      imageUrl: data['imageUrl']?.toString(),
      name: (data['name'] ?? 'Unnamed Item').toString(),
      price: price,
      representationType: (data['representationType'] ?? '').toString(),
      soldBy: (data['soldBy'] ?? 'each').toString(),
      stockQty: stockQty,
      trackStock: data['trackStock'] == true,
      rawData: Map<String, dynamic>.from(data),
    );
  }
}