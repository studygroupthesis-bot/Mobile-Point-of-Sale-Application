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

  String _selectedCategory = 'All';
  String _search = '';

  /// itemId -> qty
  final Map<String, int> _cart = {};

  late final Future<_StaffStoreAccess> _storeAccessFuture;

  // Basket + bottom nav reserved layout values
  static const double _basketHeight = 56;
  static const double _basketBottomOffset = 56;
  static const double _reservedBottomSpace =
      _basketHeight + _basketBottomOffset + 14;

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
    final storeName =
        (storeData['business_name'] ?? storeData['storeName'] ?? 'Store')
            .toString()
            .trim();

    final storeLogoUrl = (storeData['logoUrl'] ??
            storeData['storeLogoUrl'] ??
            storeData['imageUrl'] ??
            '')
        .toString()
        .trim();

    return _StaffStoreAccess(
      storeId: storeId,
      storeName: storeName.isEmpty ? 'Store' : storeName,
      role: role,
      storeLogoUrl: storeLogoUrl,
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

  void _showMenuMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  void _handleMenuAction(String value, _StaffStoreAccess access) {
    final canManageInventory =
        access.role == 'admin' || access.role == 'staff';

    if (!canManageInventory) {
      _showMenuMessage('You do not have permission to manage inventory.');
      return;
    }

    switch (value) {
      case 'add':
        _showMenuMessage('Add Item clicked.');
        break;
      case 'edit':
        _showMenuMessage('Edit Item clicked.');
        break;
      case 'delete':
        _showMenuMessage('Delete Item clicked.');
        break;
    }
  }

  void _openCartSheet(List<InventoryItem> allItems) {
    final parentContext = context;

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        final maxSheetHeight = media.size.height - media.padding.top - 8;
        final desiredSheetHeight = media.size.height * 0.90;
        final sheetHeight =
            desiredSheetHeight > maxSheetHeight
                ? maxSheetHeight
                : desiredSheetHeight;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedItems = allItems
                .where((item) => (_cart[item.id] ?? 0) > 0)
                .toList();

            final totalItems = _totalItems;
            final totalAmount = _totalAmount(allItems);

            return SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: media.viewInsets.bottom,
                ),
                child: Container(
                  height: sheetHeight + media.padding.bottom,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 54,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Text(
                              'Cart',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: selectedItems.isEmpty
                            ? const Center(
                                child: Text(
                                  'Your basket is empty.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  20,
                                ),
                                itemCount: selectedItems.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = selectedItems[index];
                                  final qty = _cart[item.id] ?? 0;
                                  final subtotal = item.price * qty;

                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x14000000),
                                          blurRadius: 14,
                                          offset: Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        _ProductThumb(
                                          item: item,
                                          size: 62,
                                          radius: 16,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _peso(item.price),
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Subtotal: ${_peso(subtotal)}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE9F6F4),
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _CartQtyButton(
                                                icon: Icons.remove,
                                                onTap: () {
                                                  _removeFromCart(item);
                                                  setModalState(() {});
                                                },
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                ),
                                                child: Text(
                                                  '$qty',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              _CartQtyButton(
                                                icon: Icons.add,
                                                onTap: () {
                                                  _addToCart(item);
                                                  setModalState(() {});
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          14,
                          20,
                          20 + media.padding.bottom,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x10000000),
                              blurRadius: 10,
                              offset: Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Items: $totalItems',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _peso(totalAmount),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF309E95),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: selectedItems.isEmpty
                                    ? null
                                    : () {
                                        Navigator.pop(sheetContext);
                                        Navigator.push(
                                          parentContext,
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF309E95),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  'Proceed to Transaction',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingScaffold() {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F5),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFFBFE9E3),
              Color(0xFFF1F3F4),
            ],
          ),
        ),
        child: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(
              color: Color(0xFF309E95),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageScaffold(String message) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F5),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFFBFE9E3),
              Color(0xFFF1F3F4),
            ],
          ),
        ),
        child: SafeArea(
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
      ),
    );
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
        final canManageInventory =
            access.role == 'admin' || access.role == 'staff';

        return Scaffold(
          backgroundColor: const Color(0xFFF2F5F5),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFBFE9E3),
                  Color(0xFFF1F3F4),
                ],
              ),
            ),
            child: SafeArea(
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

                    return item.name
                            .toLowerCase()
                            .contains(_search.toLowerCase()) ||
                        item.category
                            .toLowerCase()
                            .contains(_search.toLowerCase()) ||
                        item.barcode
                            .toLowerCase()
                            .contains(_search.toLowerCase());
                  }).toList();

                  final sectionMap = _buildSections(searchedItems);
                  final totalAmount = _totalAmount(allItems);

                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        bottom: _reservedBottomSpace + safeBottom,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            18,
                            18,
                            18,
                            24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _StoreAvatar(
                                    storeName: storeName,
                                    storeLogoUrl: access.storeLogoUrl,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      storeName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                        shadows: [
                                          Shadow(
                                            color: Color(0x22000000),
                                            blurRadius: 8,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (canManageInventory)
                                    PopupMenuButton<String>(
                                      tooltip: 'Inventory actions',
                                      onSelected: (value) {
                                        _handleMenuAction(value, access);
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem<String>(
                                          value: 'add',
                                          child: Text('Add Item'),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'edit',
                                          child: Text('Edit Item'),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Text('Delete Item'),
                                        ),
                                      ],
                                      icon: const Icon(
                                        Icons.menu_rounded,
                                        size: 34,
                                        color: Colors.black,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.lock_outline,
                                      size: 28,
                                      color: Colors.black45,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 22),

                              Container(
                                height: 58,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F7F7),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x20000000),
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search',
                                    hintStyle: TextStyle(
                                      color: Colors.black.withOpacity(0.35),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 18,
                                    ),
                                    suffixIcon: const Padding(
                                      padding: EdgeInsets.only(right: 12),
                                      child: Icon(
                                        Icons.search_rounded,
                                        size: 34,
                                        color: Colors.black,
                                      ),
                                    ),
                                    suffixIconConstraints:
                                        const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 28),
                              const Text(
                                'Categories',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 16),

                              SizedBox(
                                height: 142,
                                child: ListView.separated(
                                  padding: const EdgeInsets.only(right: 18),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: categories.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 16),
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

                              const SizedBox(height: 18),

                              if (sectionMap.isEmpty)
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 50),
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
                                  final category = entry.key;
                                  final items = entry.value;

                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 22),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          category,
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        SizedBox(
                                          height: 248,
                                          child: ListView.separated(
                                            padding: const EdgeInsets.only(
                                              right: 18,
                                            ),
                                            scrollDirection: Axis.horizontal,
                                            itemCount: items.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(width: 16),
                                            itemBuilder: (context, index) {
                                              final item = items[index];
                                              final qty = _qtyOf(item.id);

                                              return _StaffItemCard(
                                                item: item,
                                                qty: qty,
                                                onAdd: () =>
                                                    _addToCart(item),
                                                peso: _peso,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: _basketBottomOffset + safeBottom,
                        child: GestureDetector(
                          onTap: () => _openCartSheet(allItems),
                          child: Container(
                            height: _basketHeight,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 22),
                            decoration: BoxDecoration(
                              color: const Color(0xFF309E95),
                              borderRadius: BorderRadius.circular(29),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x20000000),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
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
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StaffStoreAccess {
  final String storeId;
  final String storeName;
  final String role;
  final String storeLogoUrl;

  const _StaffStoreAccess({
    required this.storeId,
    required this.storeName,
    required this.role,
    required this.storeLogoUrl,
  });
}

class _StoreAvatar extends StatelessWidget {
  final String storeName;
  final String storeLogoUrl;

  const _StoreAvatar({
    required this.storeName,
    required this.storeLogoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        storeName.trim().isEmpty ? 'S' : storeName.trim()[0].toUpperCase();

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
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
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB11C8E),
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB11C8E),
                  ),
                ),
              ),
      ),
    );
  }
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
    final bg = selected ? const Color(0xFF5A9896) : const Color(0xFFB0D8D6);
    final fg = selected ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 118,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
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
                        size: 54,
                        color: fg,
                      )
                    : _CategoryThumb(
                        category: category,
                        items: items,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
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

class _StaffItemCard extends StatelessWidget {
  final InventoryItem item;
  final int qty;
  final VoidCallback onAdd;
  final String Function(num value) peso;

  const _StaffItemCard({
    required this.item,
    required this.qty,
    required this.onAdd,
    required this.peso,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFD8E1E5),
          borderRadius: BorderRadius.circular(16),
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
                Center(
                  child: _ProductThumb(
                    item: item,
                    size: 88,
                    radius: 14,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  peso(item.price),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    if (item.trackStock && item.stockQty != null)
                      Text(
                        'Stock: ${item.stockQty}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFF33AAA0),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (qty > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF309E95),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'x$qty',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
        child: Image.network(
          item.imageUrl!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _FallbackItemVisual(
            item: item,
            size: size,
            radius: radius,
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

class _CartQtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CartQtyButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFF309E95),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
      ),
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
        color: Colors.black.withOpacity(0.35),
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
      if (item.category.toLowerCase() == category.toLowerCase()) {
        first = item;
        break;
      }
    }

    if (first == null) {
      return const Icon(
        Icons.category_outlined,
        size: 42,
        color: Colors.black87,
      );
    }

    return _ProductThumb(
      item: first,
      size: 58,
      radius: 12,
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
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Transaction',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: selectedItems.isEmpty
          ? const Center(
              child: Text(
                'Your basket is empty.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: selectedItems.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = selectedItems[index];
                      final qty = cart[item.id] ?? 0;
                      final subtotal = item.price * qty;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            _ProductThumb(
                              item: item,
                              size: 56,
                              radius: 14,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Qty: $qty',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _peso(subtotal),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Items: $totalItems',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _peso(totalAmount),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF309E95),
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