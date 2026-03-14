import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EmployeeInventoryScreen extends StatefulWidget {
  const EmployeeInventoryScreen({super.key});

  @override
  State<EmployeeInventoryScreen> createState() =>
      _EmployeeInventoryScreenState();
}

class _EmployeeInventoryScreenState extends State<EmployeeInventoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'All';
  String _search = '';

  /// itemId -> qty
  final Map<String, int> _cart = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
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

  int get _totalItems {
    return _cart.values.fold(0, (sum, qty) => sum + qty);
  }

  double _totalAmount(List<InventoryItem> items) {
    double total = 0;
    for (final item in items) {
      final qty = _cart[item.id] ?? 0;
      total += item.price * qty;
    }
    return total;
  }

  String _peso(num value) => '₱${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F6),
      body: SafeArea(
        top: true,
        bottom: false,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('items')
              .orderBy('name')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Error loading items: ${snapshot.error}'),
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
                  .map((e) => e.category.trim())
                  .where((e) => e.isNotEmpty),
            }.toList();

            final filteredItems = allItems.where((item) {
              final matchesCategory = _selectedCategory == 'All'
                  ? true
                  : item.category.toLowerCase() ==
                      _selectedCategory.toLowerCase();

              final matchesSearch = _search.trim().isEmpty
                  ? true
                  : item.name.toLowerCase().contains(_search.toLowerCase());

              return matchesCategory && matchesSearch;
            }).toList();

            final totalAmount = _totalAmount(allItems);

            return LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                final isSmallPhone = screenWidth < 360;

                final horizontalPadding = isSmallPhone ? 16.0 : 20.0;
                final gridSpacing = isSmallPhone ? 10.0 : 12.0;
                final itemAspectRatio = isSmallPhone ? 0.78 : 0.82;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    MediaQuery.of(context).padding.bottom + 18,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// HEADER
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(23),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(23),
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.store,
                                  color: Color(0xFF055A5B),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'DALI',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.menu, size: 28),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      /// SEARCH
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() => _search = value.trim());
                          },
                          decoration: const InputDecoration(
                            hintText: 'Search item',
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            suffixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        height: 106,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            final selected = _selectedCategory == category;

                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedCategory = category);
                              },
                              child: Container(
                                width: 92,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF5D9F9C)
                                      : const Color(0xFFC2E6E3),
                                  borderRadius: BorderRadius.circular(12),
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
                                    if (category == 'All')
                                      const Icon(
                                        Icons.grid_view_rounded,
                                        size: 36,
                                        color: Color(0xFF4B8D8C),
                                      )
                                    else
                                      Expanded(
                                        child: _CategoryThumb(
                                          category: category,
                                          items: allItems,
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    Text(
                                      category,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: selected
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        _selectedCategory,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (filteredItems.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          alignment: Alignment.center,
                          child: const Text(
                            'No items found.',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredItems.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: gridSpacing,
                            mainAxisSpacing: gridSpacing,
                            childAspectRatio: itemAspectRatio,
                          ),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final qty = _qtyOf(item.id);

                            return _EmployeeItemCard(
                              item: item,
                              qty: qty,
                              onAdd: () => _addToCart(item),
                              onRemove: () => _removeFromCart(item),
                              peso: _peso,
                            );
                          },
                        ),

                      const SizedBox(height: 18),

                      /// BASKET BAR
                      GestureDetector(
                        onTap: _totalItems == 0
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EmployeeTransactionScreen(
                                      allItems: allItems,
                                      cart: _cart,
                                    ),
                                  ),
                                );
                              },
                        child: Opacity(
                          opacity: _totalItems == 0 ? 0.85 : 1,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF35A7A0),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Basket - $_totalItems ${_totalItems == 1 ? 'Item' : 'Items'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  _peso(totalAmount),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      /// TEMP BOTTOM NAV LOOK
                      Container(
                        height: 70,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF083B73),
                          borderRadius: BorderRadius.circular(35),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Icon(Icons.home_outlined,
                                    color: Colors.white, size: 28),
                                Icon(Icons.receipt_long_outlined,
                                    color: Colors.white, size: 28),
                                SizedBox(width: 54),
                                Icon(Icons.person_outline,
                                    color: Colors.white, size: 28),
                              ],
                            ),
                            Positioned(
                              top: -20,
                              child: Container(
                                width: 66,
                                height: 66,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF083B73),
                                  border: Border.all(
                                    color: const Color(0xFFF0F4F6),
                                    width: 4,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: Colors.white,
                                  size: 30,
                                ),
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
          },
        ),
      ),
    );
  }
}

class _EmployeeItemCard extends StatelessWidget {
  final InventoryItem item;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final String Function(num value) peso;

  const _EmployeeItemCard({
    required this.item,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
    required this.peso,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EFF1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: item.imageUrl != null && item.imageUrl!.trim().isNotEmpty
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _FallbackItemVisual(item: item),
                    )
                  : _FallbackItemVisual(item: item),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            peso(item.price),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: qty == 0
                ? InkWell(
                    onTap: onAdd,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFF35A7A0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF9BA8AD)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: onRemove,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '-',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '$qty',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        InkWell(
                          onTap: onAdd,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '+',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
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
        width: 56,
        height: 72,
        decoration: BoxDecoration(
          color: Color(item.colorValue!),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black12),
        ),
      );
    }

    return const Icon(
      Icons.inventory_2_outlined,
      size: 56,
      color: Color(0xFF7A8A90),
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
    final first = items.cast<InventoryItem?>().firstWhere(
          (e) => e?.category.toLowerCase() == category.toLowerCase(),
          orElse: () => null,
        );

    if (first == null) {
      return const Icon(
        Icons.category_outlined,
        size: 34,
        color: Color(0xFF4B8D8C),
      );
    }

    if (first.imageUrl != null && first.imageUrl!.trim().isNotEmpty) {
      return Image.network(
        first.imageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _FallbackItemVisual(item: first),
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

  factory InventoryItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

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

/// TEMP transaction screen so basket navigation already works
class EmployeeTransactionScreen extends StatelessWidget {
  final List<InventoryItem> allItems;
  final Map<String, int> cart;

  const EmployeeTransactionScreen({
    super.key,
    required this.allItems,
    required this.cart,
  });

  String _peso(num value) => '₱${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final selectedItems = allItems.where((e) => (cart[e.id] ?? 0) > 0).toList();

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