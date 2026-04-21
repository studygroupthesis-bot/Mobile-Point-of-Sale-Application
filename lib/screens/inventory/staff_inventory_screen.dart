import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../transaction/transaction_screen.dart';

enum InventoryMenuAction {
  stockLogs,
  createItem,
  editItem,
  inventoryOverview,
  batchDetails,
  addStock,
  reduceStock,
  pullOutStock,
}

enum InventoryMovementType {
  addStock,
  reduceStock,
  pullOutStock,
}

class StaffInventoryScreen extends StatefulWidget {
  const StaffInventoryScreen({super.key});

  @override
  State<StaffInventoryScreen> createState() => _StaffInventoryScreenState();
}

class _StaffInventoryScreenState extends State<StaffInventoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  late final Future<_StaffStoreAccess> _storeAccessFuture;

  final Map<String, int> _cart = {};

  String _search = '';
  String _selectedCategory = 'All';

  static const double _basketHeight = 48;
  static const double _basketBottomOffset = 4;
  static const double _reservedBottomSpace =
      _basketHeight + _basketBottomOffset + 10;

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

  bool _isAdminLikeRole(String role) {
    final normalized = role.trim().toLowerCase();
    return normalized == 'admin' || normalized == 'owner';
  }

  Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  bool _readPermissionFromMaps(
    List<Map<String, dynamic>> maps,
    List<String> possibleKeys,
    bool fallback,
  ) {
    for (final map in maps) {
      for (final key in possibleKeys) {
        final value = map[key];
        if (value is bool) return value;
      }
    }
    return fallback;
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

    final userData = userSnap.data() ?? <String, dynamic>{};

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

    final permissionsRoot = _asStringMap(userData['permissions']);
    final inventoryPermissions = _asStringMap(permissionsRoot['inventory']);

    final isAdmin = _isAdminLikeRole(role);

    final canViewInventory = isAdmin
        ? true
        : _readPermissionFromMaps(
            [inventoryPermissions, permissionsRoot, userData],
            [
              'viewInventory',
              'canViewInventory',
              'view_inventory',
              'can_view_inventory',
            ],
            true,
          );

    final canAddStock = isAdmin
        ? true
        : _readPermissionFromMaps(
            [inventoryPermissions, permissionsRoot, userData],
            [
              'addStock',
              'canAddStock',
              'add_stock',
              'can_add_stock',
            ],
            false,
          );

    final canReduceStock = isAdmin
        ? true
        : _readPermissionFromMaps(
            [inventoryPermissions, permissionsRoot, userData],
            [
              'reduceStock',
              'canReduceStock',
              'reduce_stock',
              'can_reduce_stock',
            ],
            false,
          );

    final canPullOutStock = isAdmin
        ? true
        : _readPermissionFromMaps(
            [inventoryPermissions, permissionsRoot, userData],
            [
              'pullOutStock',
              'canPullOutStock',
              'pull_out_stock',
              'can_pull_out_stock',
            ],
            false,
          );

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

    return _StaffStoreAccess(
      storeId: storeId,
      storeName: storeName.isEmpty ? 'Store' : storeName,
      role: role,
      storeLogoUrl: storeLogoUrl,
      canViewInventory: canViewInventory,
      canAddStock: canAddStock,
      canReduceStock: canReduceStock,
      canPullOutStock: canPullOutStock,
    );
  }

  int _qtyOf(String itemId) => _cart[itemId] ?? 0;

  int get _totalItems => _cart.values.fold(0, (sum, qty) => sum + qty);

  String _peso(num value) => '₱${value.toStringAsFixed(2)}';

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

  double _totalAmount(List<InventoryItem> items) {
    double total = 0;
    for (final item in items) {
      total += item.price * (_cart[item.id] ?? 0);
    }
    return total;
  }

  List<CartItem> _buildTransactionCartItems(List<InventoryItem> items) {
    return items
        .where((item) => (_cart[item.id] ?? 0) > 0)
        .map(
          (item) => CartItem(
            itemId: item.id,
            name: item.name,
            price: item.price,
            barcode: item.barcode,
            qty: _cart[item.id] ?? 0,
          ),
        )
        .toList();
  }

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
      final keys = grouped.keys.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      return {
        for (final key in keys) key: grouped[key]!,
      };
    }

    final filtered = grouped.entries.where(
      (entry) => entry.key.toLowerCase() == _selectedCategory.toLowerCase(),
    );

    return {
      for (final entry in filtered) entry.key: entry.value,
    };
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _movementTitle(InventoryMovementType type) {
    switch (type) {
      case InventoryMovementType.addStock:
        return 'Add Stock';
      case InventoryMovementType.reduceStock:
        return 'Reduce Stock';
      case InventoryMovementType.pullOutStock:
        return 'Pull Out Stock';
    }
  }

  String _movementValue(InventoryMovementType type) {
    switch (type) {
      case InventoryMovementType.addStock:
        return 'add_stock';
      case InventoryMovementType.reduceStock:
        return 'reduce_stock';
      case InventoryMovementType.pullOutStock:
        return 'pull_out_stock';
    }
  }

  int _calculateNewStock({
    required InventoryMovementType type,
    required int currentStock,
    required int quantity,
  }) {
    switch (type) {
      case InventoryMovementType.addStock:
        return currentStock + quantity;
      case InventoryMovementType.reduceStock:
      case InventoryMovementType.pullOutStock:
        final newStock = currentStock - quantity;
        if (newStock < 0) {
          throw Exception('Quantity exceeds current stock.');
        }
        return newStock;
    }
  }

  Future<void> _applyMovement({
    required InventoryMovementType type,
    required InventoryItem item,
    required int quantity,
    required String note,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not logged in.');
    }

    final access = await _storeAccessFuture;
    final firestore = FirebaseFirestore.instance;

    final itemRef = firestore
        .collection('stores')
        .doc(access.storeId)
        .collection('items')
        .doc(item.id);

    final movementRef = firestore
        .collection('stores')
        .doc(access.storeId)
        .collection('stock_movements')
        .doc();

    await firestore.runTransaction((transaction) async {
      final itemSnap = await transaction.get(itemRef);

      if (!itemSnap.exists) {
        throw Exception('Item not found.');
      }

      final data = itemSnap.data() ?? <String, dynamic>{};

      final rawStock = data['stockQty'] ?? data['stock'] ?? data['quantity'];
      int currentStock = 0;

      if (rawStock is int) {
        currentStock = rawStock;
      } else if (rawStock is double) {
        currentStock = rawStock.toInt();
      } else if (rawStock is String) {
        currentStock = int.tryParse(rawStock) ?? 0;
      }

      final newStock = _calculateNewStock(
        type: type,
        currentStock: currentStock,
        quantity: quantity,
      );

      transaction.update(itemRef, {
        'stockQty': newStock,
        'stock': newStock,
        'quantity': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(movementRef, {
        'itemId': item.id,
        'itemName': item.name,
        'type': _movementValue(type),
        'quantity': quantity,
        'previousStock': currentStock,
        'newStock': newStock,
        'note': note,
        'storeId': access.storeId,
        'storeName': access.storeName,
        'performedBy': user.uid,
        'performedByRole': access.role,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  List<PopupMenuEntry<InventoryMenuAction>> _buildInventoryMenuItems(
    _StaffStoreAccess access,
  ) {
    if (access.isAdminLike) {
      return const [
        PopupMenuItem<InventoryMenuAction>(
          value: InventoryMenuAction.stockLogs,
          child: Text('Stock Logs'),
        ),
        PopupMenuItem<InventoryMenuAction>(
          value: InventoryMenuAction.createItem,
          child: Text('Create Item'),
        ),
        PopupMenuItem<InventoryMenuAction>(
          value: InventoryMenuAction.editItem,
          child: Text('Edit Item'),
        ),
        PopupMenuItem<InventoryMenuAction>(
          value: InventoryMenuAction.inventoryOverview,
          child: Text('Inventory Overview'),
        ),
        PopupMenuItem<InventoryMenuAction>(
          value: InventoryMenuAction.batchDetails,
          child: Text('Batch Details'),
        ),
        PopupMenuDivider(),
        PopupMenuItem<InventoryMenuAction>(
          value: InventoryMenuAction.addStock,
          child: Text('Add Stock'),
        ),
        PopupMenuItem<InventoryMenuAction>(
          value: InventoryMenuAction.reduceStock,
          child: Text('Reduce Stock'),
        ),
        PopupMenuItem<InventoryMenuAction>(
          value: InventoryMenuAction.pullOutStock,
          child: Text('Pull Out Stock'),
        ),
      ];
    }

    final items = <PopupMenuEntry<InventoryMenuAction>>[];

    if (access.canAddStock) {
      items.add(
        const PopupMenuItem<InventoryMenuAction>(
          value: InventoryMenuAction.addStock,
          child: Text('Add Stock'),
        ),
      );
    }

    if (access.canReduceStock) {
      items.add(
        const PopupMenuItem<InventoryMenuAction>(
          value: InventoryMenuAction.reduceStock,
          child: Text('Reduce Stock'),
        ),
      );
    }

    if (access.canPullOutStock) {
      items.add(
        const PopupMenuItem<InventoryMenuAction>(
          value: InventoryMenuAction.pullOutStock,
          child: Text('Pull Out Stock'),
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        const PopupMenuItem<InventoryMenuAction>(
          enabled: false,
          child: Text('No actions available'),
        ),
      );
    }

    return items;
  }

  Future<void> _openMovementItemPicker({
    required InventoryMovementType type,
    required List<InventoryItem> allItems,
  }) async {
    final stockManagedItems = allItems.where((item) => item.trackStock).toList();

    if (stockManagedItems.isEmpty) {
      _showMessage('No stock-managed items available.');
      return;
    }

    final selectedItem = await showModalBottomSheet<InventoryItem>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: stockManagedItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = stockManagedItems[index];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: const Color(0xFFF4F7F7),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                leading: _ProductThumb(
                  item: item,
                  size: 48,
                  radius: 10,
                ),
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('Current stock: ${item.stockQty ?? 0}'),
                onTap: () => Navigator.pop(context, item),
              );
            },
          ),
        );
      },
    );

    if (selectedItem == null) return;

    await _openMovementEntryDialog(type: type, item: selectedItem);
  }

  Future<void> _openMovementEntryDialog({
    required InventoryMovementType type,
    required InventoryItem item,
  }) async {
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final qty = int.tryParse(qtyCtrl.text.trim());

              if (qty == null || qty <= 0) {
                setDialogState(() {
                  errorText = 'Enter a valid quantity.';
                });
                return;
              }

              final currentStock = item.stockQty ?? 0;
              if ((type == InventoryMovementType.reduceStock ||
                      type == InventoryMovementType.pullOutStock) &&
                  qty > currentStock) {
                setDialogState(() {
                  errorText = 'Quantity exceeds current stock.';
                });
                return;
              }

              setDialogState(() {
                isSaving = true;
                errorText = null;
              });

              try {
                await _applyMovement(
                  type: type,
                  item: item,
                  quantity: qty,
                  note: noteCtrl.text.trim(),
                );

                if (!mounted) return;

                Navigator.of(dialogContext).pop();
                _showMessage('${_movementTitle(type)} saved for ${item.name}.');
              } catch (e) {
                setDialogState(() {
                  isSaving = false;
                  errorText = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return AlertDialog(
              title: Text(_movementTitle(type)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Current stock: ${item.stockQty ?? 0}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : submit,
                  child: Text(isSaving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    qtyCtrl.dispose();
    noteCtrl.dispose();
  }

  void _handleMenuAction(
    InventoryMenuAction action,
    _StaffStoreAccess access,
    List<InventoryItem> allItems,
  ) {
    if (!access.shouldShowMenu) {
      _showMessage('You do not have permission to manage inventory.');
      return;
    }

    switch (action) {
      case InventoryMenuAction.stockLogs:
        _showMessage('Stock Logs clicked.');
        break;
      case InventoryMenuAction.createItem:
        _showMessage('Create Item clicked.');
        break;
      case InventoryMenuAction.editItem:
        _showMessage('Edit Item clicked.');
        break;
      case InventoryMenuAction.inventoryOverview:
        _showMessage('Inventory Overview clicked.');
        break;
      case InventoryMenuAction.batchDetails:
        _showMessage('Batch Details clicked.');
        break;
      case InventoryMenuAction.addStock:
        _openMovementItemPicker(
          type: InventoryMovementType.addStock,
          allItems: allItems,
        );
        break;
      case InventoryMenuAction.reduceStock:
        _openMovementItemPicker(
          type: InventoryMovementType.reduceStock,
          allItems: allItems,
        );
        break;
      case InventoryMenuAction.pullOutStock:
        _openMovementItemPicker(
          type: InventoryMovementType.pullOutStock,
          allItems: allItems,
        );
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

        final footerBottomPadding = media.padding.bottom > 0
            ? (media.padding.bottom * 0.35) + 8
            : 14.0;

        return SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final selectedItems = allItems
                    .where((item) => (_cart[item.id] ?? 0) > 0)
                    .toList();

                final totalItems = _totalItems;
                final totalAmount = _totalAmount(allItems);

                return Container(
                  height: sheetHeight,
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
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
                          footerBottomPadding,
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

                                        final selectedCartItems =
                                            _buildTransactionCartItems(allItems);

                                        Navigator.push(
                                          parentContext,
                                          MaterialPageRoute(
                                            builder: (_) => TransactionScreen(
                                              isActive: true,
                                              initialCart: selectedCartItems,
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
                );
              },
            ),
          ),
        );
      },
    );
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

  Widget _buildCategorySection({
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
              height: 205,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                padding: const EdgeInsets.only(right: 18),
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final qty = _qtyOf(item.id);

                  return SizedBox(
                    width: 148,
                    child: _StaffItemCardCompact(
                      item: item,
                      qty: qty,
                      onAdd: () => _addToCart(item),
                      peso: _peso,
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
                childAspectRatio: 0.74,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                final qty = _qtyOf(item.id);

                return _StaffItemCardCompact(
                  item: item,
                  qty: qty,
                  onAdd: () => _addToCart(item),
                  peso: _peso,
                );
              },
            ),
        ],
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

        if (!access.canViewInventory) {
          return _buildMessageScaffold(
            'You do not have permission to view inventory.',
          );
        }

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

                  final q = _search.toLowerCase();
                  return item.name.toLowerCase().contains(q) ||
                      item.category.toLowerCase().contains(q) ||
                      item.barcode.toLowerCase().contains(q);
                }).toList();

                final sectionMap = _buildSections(searchedItems);
                final totalAmount = _totalAmount(allItems);

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
                                if (access.shouldShowMenu)
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color:
                                          const Color(0xFFFFFFFF).withAlpha(128),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: PopupMenuButton<InventoryMenuAction>(
                                      tooltip: 'Inventory actions',
                                      color: Colors.white,
                                      padding: EdgeInsets.zero,
                                      onSelected: (value) {
                                        _handleMenuAction(
                                          value,
                                          access,
                                          allItems,
                                        );
                                      },
                                      itemBuilder: (context) =>
                                          _buildInventoryMenuItems(access),
                                      icon: const Icon(
                                        Icons.menu_rounded,
                                        size: 24,
                                        color: Colors.black,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color:
                                          const Color(0xFFFFFFFF).withAlpha(128),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.lock_outline,
                                      size: 20,
                                      color: Colors.black45,
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

                                  return _StaffCategoryCardCompact(
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
                      bottom: _basketBottomOffset + safeBottom,
                      child: GestureDetector(
                        onTap: () => _openCartSheet(allItems),
                        child: Container(
                          height: _basketHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                _peso(totalAmount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
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
  final bool canViewInventory;
  final bool canAddStock;
  final bool canReduceStock;
  final bool canPullOutStock;

  const _StaffStoreAccess({
    required this.storeId,
    required this.storeName,
    required this.role,
    required this.storeLogoUrl,
    required this.canViewInventory,
    required this.canAddStock,
    required this.canReduceStock,
    required this.canPullOutStock,
  });

  bool get isAdminLike {
    final normalized = role.trim().toLowerCase();
    return normalized == 'admin' || normalized == 'owner';
  }

  bool get hasStaffInventoryActions =>
      canAddStock || canReduceStock || canPullOutStock;

  bool get shouldShowMenu => isAdminLike || hasStaffInventoryActions;
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

class _StaffCategoryCardCompact extends StatelessWidget {
  final String category;
  final bool selected;
  final List<InventoryItem> items;
  final VoidCallback onTap;

  const _StaffCategoryCardCompact({
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

class _StaffItemCardCompact extends StatelessWidget {
  final InventoryItem item;
  final int qty;
  final VoidCallback onAdd;
  final String Function(num value) peso;

  const _StaffItemCardCompact({
    required this.item,
    required this.qty,
    required this.onAdd,
    required this.peso,
  });

  @override
  Widget build(BuildContext context) {
    final stock = item.stockQty ?? 0;
    final hasStock = item.trackStock && item.stockQty != null;
    final isOutOfStock = hasStock && stock <= 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
              const SizedBox(height: 10),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.15,
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
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: hasStock
                        ? Text(
                            'Stock: $stock',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isOutOfStock ? Colors.red : Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  GestureDetector(
                    onTap: isOutOfStock ? null : onAdd,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? Colors.grey.withAlpha(160)
                            : const Color(0xFFFFFFFF).withAlpha(210),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: isOutOfStock
                            ? Colors.white70
                            : const Color(0xFF33AAA0),
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
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF309E95),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'x$qty',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
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
    final data = doc.data() ?? <String, dynamic>{};

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
    );
  }
}