import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StaffInventoryScreen extends StatefulWidget {
  const StaffInventoryScreen({super.key});

  @override
  State<StaffInventoryScreen> createState() => _StaffInventoryScreenState();
}

class _StaffInventoryScreenState extends State<StaffInventoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const String _gradientAsset = 'assets/Gradient.png';

  String _selectedCategory = 'All';
  String _search = '';

  /// itemId -> qty
  final Map<String, int> _cart = {};

  late final Future<_StaffStoreAccess> _storeAccessFuture;

  @override
  void initState() {
    super.initState();
    _storeAccessFuture = _loadStoreAccess();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_StaffStoreAccess> _loadStoreAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not logged in.');
    }

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userSnap.exists) {
      throw Exception('User profile not found.');
    }

    final userData = userSnap.data() ?? {};
    final storeId = (userData['storeId'] ?? '').toString().trim();
    final role = (userData['role'] ?? '').toString().trim().toLowerCase();

    if (storeId.isEmpty) {
      throw Exception(
        'Missing storeId in users/${user.uid}. Add storeId to the user profile.',
      );
    }

    if (role.isEmpty) {
      throw Exception(
        'Missing role in users/${user.uid}. Add role to the user profile.',
      );
    }

    final storeSnap = await FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .get();

    final storeData = storeSnap.data() ?? {};
    final storeName = (storeData['business_name'] ??
            storeData['storeName'] ??
            'Store')
        .toString()
        .trim();

    return _StaffStoreAccess(
      storeId: storeId,
      storeName: storeName.isEmpty ? 'Store' : storeName,
    );
  }

  Widget _buildGradientBubble({
    required double size,
  }) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.68,
        child: Image.asset(
          _gradientAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildLoadingScaffold() {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F6),
      body: Stack(
        children: [
          Positioned(
            top: -40,
            left: -70,
            child: _buildGradientBubble(size: 220),
          ),
          Positioned(
            bottom: 120,
            right: -80,
            child: _buildGradientBubble(size: 240),
          ),
          const SafeArea(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageScaffold(String message) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F6),
      body: Stack(
        children: [
          Positioned(
            top: -40,
            left: -70,
            child: _buildGradientBubble(size: 220),
          ),
          Positioned(
            bottom: 120,
            right: -80,
            child: _buildGradientBubble(size: 240),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _qtyOf(String itemId) => _cart[itemId] ?? 0;

  void _addToCart(InventoryItem item) {
    setState(() {
      if (item.trackStock && item.stockQty != null) {
        final currentQty = _cart[item.id] ?? 0;
        if (currentQty >= item.stockQty!) return;
      }
      _cart[item.id] = (_cart[item.id] ?? 0) + 1;
    });
  }

  void _removeFromCart(InventoryItem item) {
    setState(() {
      final currentQty = _cart[item.id] ?? 0;
      if (currentQty <= 1) {
        _cart.remove(item.id);
      } else {
        _cart[item.id] = currentQty - 1;
      }
    });
  }

  int get _totalItems => _cart.values.fold(0, (sum, qty) => sum + qty);

  double _totalAmount(List<InventoryItem> items) {
    double total = 0;
    for (final item in items) {
      final qty = _cart[item.id] ?? 0;
      total += item.price * qty;
    }
    return total;
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

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return FutureBuilder<_StaffStoreAccess>(
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
          backgroundColor: const Color(0xFFF0F4F6),
          body: Stack(
            children: [
              Positioned(
                top: -40,
                left: -70,
                child: _buildGradientBubble(size: 220),
              ),
              Positioned(
                bottom: 120,
                right: -80,
                child: _buildGradientBubble(size: 240),
              ),
              SafeArea(
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
                          'Error loading items:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
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
                      return item.name
                          .toLowerCase()
                          .contains(_search.toLowerCase());
                    }).toList();

                    final sectionMap = _buildSections(searchedItems);
                    final totalAmount = _totalAmount(allItems);

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Inventory / Staff',
                            style: TextStyle(
                              color: Color(0xFFE9BCBC),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F4F5),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Stack(
                                children: [
                                  SingleChildScrollView(
                                    padding: EdgeInsets.fromLTRB(
                                      14,
                                      14,
                                      14,
                                      150 + safeBottom,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 34,
                                              height: 34,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.shopping_bag_rounded,
                                                color: Color(0xFFE06AA8),
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                storeName,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF153A39),
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () {},
                                              icon: const Icon(
                                                Icons.menu_rounded,
                                                size: 22,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        Container(
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: TextField(
                                            controller: _searchController,
                                            onChanged: (value) {
                                              setState(() {
                                                _search = value.trim();
                                              });
                                            },
                                            decoration: const InputDecoration(
                                              hintText: 'Search',
                                              prefixIcon: Icon(
                                                Icons.search,
                                                size: 20,
                                              ),
                                              border: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                vertical: 10,
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 12),

                                        const Padding(
                                          padding:
                                              EdgeInsets.only(left: 2, bottom: 8),
                                          child: Text(
                                            'Categories',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),

                                        SizedBox(
                                          height: 88,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: categories.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(width: 10),
                                            itemBuilder: (context, index) {
                                              final category = categories[index];
                                              final selected =
                                                  _selectedCategory == category;

                                              return _StaffCategoryCard(
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

                                        const SizedBox(height: 10),

                                        if (sectionMap.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 40,
                                            ),
                                            child: Center(
                                              child: Text(
                                                'No items found.',
                                                style: TextStyle(fontSize: 15),
                                              ),
                                            ),
                                          )
                                        else
                                          ...sectionMap.entries.map((entry) {
                                            final category = entry.key;
                                            final items = entry.value;

                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 16,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    category,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  GridView.builder(
                                                    shrinkWrap: true,
                                                    physics:
                                                        const NeverScrollableScrollPhysics(),
                                                    itemCount: items.length,
                                                    gridDelegate:
                                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                                      crossAxisCount: 2,
                                                      crossAxisSpacing: 10,
                                                      mainAxisSpacing: 10,
                                                      childAspectRatio: 0.83,
                                                    ),
                                                    itemBuilder:
                                                        (context, index) {
                                                      final item = items[index];
                                                      final qty =
                                                          _qtyOf(item.id);

                                                      return _StaffItemCard(
                                                        item: item,
                                                        qty: qty,
                                                        onAdd: () =>
                                                            _addToCart(item),
                                                        onRemove: () =>
                                                            _removeFromCart(
                                                          item,
                                                        ),
                                                        peso: _peso,
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                      ],
                                    ),
                                  ),

                                  Positioned(
                                    left: 14,
                                    right: 14,
                                    bottom: 100 + safeBottom,
                                    child: GestureDetector(
                                      onTap: _totalItems == 0
                                          ? null
                                          : () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      StaffTransactionScreen(
                                                    allItems: allItems,
                                                    cart: Map<String, int>.from(
                                                      _cart,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                      child: Opacity(
                                        opacity: _totalItems == 0 ? 0.92 : 1,
                                        child: Container(
                                          height: 50,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF60C0B5),
                                            borderRadius:
                                                BorderRadius.circular(26),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Basket - $_totalItems ${_totalItems == 1 ? 'Item' : 'Items'}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                _peso(totalAmount),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StaffStoreAccess {
  final String storeId;
  final String storeName;

  const _StaffStoreAccess({
    required this.storeId,
    required this.storeName,
  });
}

class _StaffCategoryCard extends StatelessWidget {
  final String category;
  final bool selected;
  final List<InventoryItem> items;
  final VoidCallback onTap;

  const _StaffCategoryCard({
    required this.category,
    required this.selected,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF79C6BC) : const Color(0xFFD7E9E7);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
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
                        size: 24,
                        color:
                            selected ? Colors.white : const Color(0xFF5AA9A0),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color:
                    selected ? Colors.white : const Color(0xFF34504C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffItemCard extends StatelessWidget {
  final InventoryItem item;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final String Function(num value) peso;

  const _StaffItemCard({
    required this.item,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
    required this.peso,
  });

  @override
  Widget build(BuildContext context) {
    final stockText = item.stockQty?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD7E9E7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: item.imageUrl != null &&
                          item.imageUrl!.trim().isNotEmpty
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              _FallbackItemVisual(item: item),
                        )
                      : _FallbackItemVisual(item: item),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                peso(item.price),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

          if (stockText.isNotEmpty)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFF60C0B5),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  stockText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

          Positioned(
            right: 0,
            top: 0,
            child: qty == 0
                ? InkWell(
                    onTap: onAdd,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6B57),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Container(
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF98AEAA)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: onRemove,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 3),
                            child: Text(
                              '-',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '$qty',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        InkWell(
                          onTap: onAdd,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 3),
                            child: Text(
                              '+',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FallbackItemVisual extends StatelessWidget {
  final InventoryItem item;

  const _FallbackItemVisual({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.representationType == 'color' && item.colorValue != null) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Color(item.colorValue!),
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFD9D6D8),
        borderRadius: BorderRadius.circular(8),
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
      if (item.category.toLowerCase() == category.toLowerCase()) {
        first = item;
        break;
      }
    }

    if (first == null) {
      return const Icon(
        Icons.category_outlined,
        size: 22,
        color: Color(0xFF5AA9A0),
      );
    }

    if (first.imageUrl != null && first.imageUrl!.trim().isNotEmpty) {
      return Image.network(
        first.imageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _FallbackItemVisual(item: first!),
      );
    }

    return _FallbackItemVisual(item: first);
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
    }

    int? stockQty;
    final rawStock = data['stockQty'];
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
    );
  }
}

class StaffTransactionScreen extends StatelessWidget {
  final List<InventoryItem> allItems;
  final Map<String, int> cart;

  const StaffTransactionScreen({
    super.key,
    required this.allItems,
    required this.cart,
  });

  String _peso(num value) => '₱${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final selectedItems =
        allItems.where((e) => (cart[e.id] ?? 0) > 0).toList();
    final totalItems = cart.values.fold(0, (sum, qty) => sum + qty);

    double totalAmount = 0;
    for (final item in selectedItems) {
      totalAmount += item.price * (cart[item.id] ?? 0);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
      ),
      body: selectedItems.isEmpty
          ? const Center(child: Text('Your basket is empty.'))
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: selectedItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = selectedItems[index];
                      final qty = cart[item.id] ?? 0;
                      final subtotal = item.price * qty;

                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text('Qty: $qty'),
                        trailing: Text(_peso(subtotal)),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Items: $totalItems',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _peso(totalAmount),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}