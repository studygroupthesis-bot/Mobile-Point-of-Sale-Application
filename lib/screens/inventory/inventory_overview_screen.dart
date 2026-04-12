import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'product_batch_details_screen.dart';

class InventoryOverviewScreen extends StatefulWidget {
  final String storeId;
  final String storeName;
  final bool isAdmin;

  const InventoryOverviewScreen({
    super.key,
    required this.storeId,
    required this.storeName,
    this.isAdmin = true,
  });

  @override
  State<InventoryOverviewScreen> createState() =>
      _InventoryOverviewScreenState();
}

class _InventoryOverviewScreenState extends State<InventoryOverviewScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  num _toNum(dynamic value) {
    if (value is int) return value;
    if (value is double) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  String _money(dynamic value) {
    final amount = _toNum(value);
    return '₱${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDFF3EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFDFF3EF),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Inventory Overview',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFDFF3EF),
              Color(0xFFCDEAE5),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8F8),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
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
                          _search = value.trim().toLowerCase();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search product name...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8F0EC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            'Product Name',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Qty',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Cost',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Price',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('stores')
                          .doc(widget.storeId)
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
                              'Firestore error:\n${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];

                        final filteredDocs = docs.where((doc) {
                          final data = doc.data();
                          final name =
                              (data['name'] ?? '').toString().toLowerCase();
                          return _search.isEmpty || name.contains(_search);
                        }).toList();

                        if (filteredDocs.isEmpty) {
                          return const Center(
                            child: Text(
                              'No products found.',
                              style: TextStyle(fontSize: 14),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: filteredDocs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final data = doc.data();

                            final productName =
                                (data['name'] ?? 'Unnamed').toString();

                            final qty = _toNum(
                              data['stockQty'] ??
                                  data['quantity'] ??
                                  data['stockOnHand'] ??
                                  data['stock'] ??
                                  0,
                            );

                            final cost = data['cost'] ?? data['unitCost'] ?? 0;
                            final price =
                                data['price'] ?? data['sellingPrice'] ?? 0;
                            final reorderLevel =
                                _toNum(data['reorderLevel'] ?? 0);

                            final isLowStock =
                                reorderLevel > 0 && qty <= reorderLevel;

                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductBatchDetailsScreen(
                                        storeId: widget.storeId,
                                        itemId: doc.id,
                                        productName: productName,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              productName,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              isLowStock
                                                  ? 'Low stock'
                                                  : 'Tap to view batch details',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isLowStock
                                                    ? Colors.red.shade700
                                                    : Colors.grey.shade600,
                                                fontWeight: isLowStock
                                                    ? FontWeight.w700
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          qty.toString(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          _money(cost),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          _money(price),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}