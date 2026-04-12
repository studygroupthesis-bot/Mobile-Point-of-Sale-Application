import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'product_batch_details_screen.dart';

class ProductBatchSelectorScreen extends StatefulWidget {
  final String storeId;
  final String storeName;

  const ProductBatchSelectorScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<ProductBatchSelectorScreen> createState() =>
      _ProductBatchSelectorScreenState();
}

class _ProductBatchSelectorScreenState
    extends State<ProductBatchSelectorScreen> {
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
          'Batch Details',
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
              padding: const EdgeInsets.all(14),
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
                    height: 48,
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
                        hintText: 'Search product...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('stores')
                          .doc(widget.storeId)
                          .collection('items')
                          .orderBy('nameLower')
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
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: filteredDocs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final data = doc.data();

                            final productName =
                                (data['name'] ?? 'No name').toString();

                            final qty = _toNum(
                              data['stockQty'] ??
                                  data['quantity'] ??
                                  data['stock'] ??
                                  0,
                            );

                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
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
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 15,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x18000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            productName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Current stock: ${qty.toString()}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded),
                                  ],
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