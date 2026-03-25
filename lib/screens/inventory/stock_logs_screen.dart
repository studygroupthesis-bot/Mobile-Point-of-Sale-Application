import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StockLogsScreen extends StatefulWidget {
  const StockLogsScreen({super.key});

  @override
  State<StockLogsScreen> createState() => _StockLogsScreenState();
}

class _StockLogsScreenState extends State<StockLogsScreen> {
  final TextEditingController _search = TextEditingController();
  String _q = '';

  late final Future<bool> _isAdminFuture;
  late final Future<String> _storeIdFuture;

  @override
  void initState() {
    super.initState();
    _isAdminFuture = _isAdmin();
    _storeIdFuture = _requireStoreId();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<String> _requireStoreId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in.');

    final snap =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final storeId = snap.data()?['storeId'] as String?;
    if (storeId == null || storeId.isEmpty) {
      throw Exception('Missing storeId in users/${user.uid}.');
    }
    return storeId;
  }

  Future<bool> _isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snap =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final role = (snap.data()?['role'] ?? '').toString().toLowerCase();
    return role == 'admin' || role == 'owner';
  }

  int _readInt(Map<String, dynamic> d, List<String> keys, {int fallback = 0}) {
    for (final k in keys) {
      final v = d[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  double _readDouble(
    Map<String, dynamic> d,
    List<String> keys, {
    double fallback = 0,
  }) {
    for (final k in keys) {
      final v = d[k];
      if (v is double) return v;
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  DateTime? _readDate(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
    }
    return null;
  }

  String _readString(
    Map<String, dynamic> d,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final k in keys) {
      final v = d[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return fallback;
  }

  String _money(double v) => '₱ ${v.toStringAsFixed(2)}';

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$mm/$dd/$yy';
  }

  String _fmtTime(DateTime? d) {
    if (d == null) return '-';
    int hour = d.hour;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final hh = hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm $suffix';
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'stock_in':
        return const Color(0xFF2E7D32);
      case 'stock_out':
        return const Color(0xFFD32F2F);
      case 'pull_out':
        return const Color(0xFF6A1B9A);
      default:
        return const Color(0xFF455A64);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7CBD0),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFF7CBD0),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              left: -90,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF9DE5DB).withOpacity(0.35),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9DE5DB).withOpacity(0.35),
                      blurRadius: 90,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: -80,
              bottom: 90,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF9DE5DB).withOpacity(0.25),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9DE5DB).withOpacity(0.25),
                      blurRadius: 90,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: FutureBuilder<bool>(
                future: _isAdminFuture,
                builder: (context, adminSnap) {
                  if (adminSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (adminSnap.data != true) {
                    return Padding(
                      padding: const EdgeInsets.all(18),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDF3EF),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Center(
                          child: Container(
                            margin: const EdgeInsets.all(20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Text(
                              'Admin only.\nYou do not have permission to view Stock Logs.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return FutureBuilder<String>(
                    future: _storeIdFuture,
                    builder: (context, storeSnap) {
                      if (storeSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (storeSnap.hasError || !storeSnap.hasData) {
                        return Padding(
                          padding: const EdgeInsets.all(18),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDDF3EF),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  'Failed to load store.\n${storeSnap.error ?? ''}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      final storeId = storeSnap.data!;

                      final logsStream = FirebaseFirestore.instance
                          .collection('stores')
                          .doc(storeId)
                          .collection('stock_logs')
                          .orderBy('created_at', descending: true)
                          .limit(300)
                          .snapshots();

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            color: const Color(0xFFDDF3EF).withOpacity(0.92),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: -70,
                                  left: -70,
                                  child: Container(
                                    width: 200,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF9DE5DB)
                                          .withOpacity(0.18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF9DE5DB)
                                              .withOpacity(0.18),
                                          blurRadius: 70,
                                          spreadRadius: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -90,
                                  bottom: 40,
                                  child: Container(
                                    width: 230,
                                    height: 230,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF9DE5DB)
                                          .withOpacity(0.14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF9DE5DB)
                                              .withOpacity(0.14),
                                          blurRadius: 80,
                                          spreadRadius: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 14, 16, 0),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          InkWell(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            onTap: () => Navigator.pop(context),
                                            child: const Padding(
                                              padding: EdgeInsets.all(8),
                                              child: Icon(
                                                Icons.arrow_back_ios_new,
                                                size: 22,
                                                color: Color(0xFF4C4C4C),
                                              ),
                                            ),
                                          ),
                                          const Expanded(
                                            child: Text(
                                              'Stock Logs',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF2D2D2D),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 38),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.85),
                                          borderRadius:
                                              BorderRadius.circular(26),
                                        ),
                                        child: TextField(
                                          controller: _search,
                                          onChanged: (v) =>
                                              setState(() => _q = v.trim()),
                                          decoration: InputDecoration(
                                            hintText:
                                                'Search product / code / encoder...',
                                            hintStyle: const TextStyle(
                                              color: Color(0xFF757575),
                                              fontSize: 14,
                                            ),
                                            isDense: true,
                                            filled: true,
                                            fillColor: Colors.transparent,
                                            prefixIcon: const Icon(
                                              Icons.search,
                                              color: Color(0xFF6E6E6E),
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(26),
                                              borderSide: BorderSide.none,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(26),
                                              borderSide: BorderSide.none,
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(26),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Expanded(
                                        child: StreamBuilder<
                                            QuerySnapshot<
                                                Map<String, dynamic>>>(
                                          stream: logsStream,
                                          builder: (context, snap) {
                                            if (snap.connectionState ==
                                                ConnectionState.waiting) {
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            }

                                            if (snap.hasError) {
                                              return Center(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(20),
                                                  child: Text(
                                                    'Failed to load stock logs.\n${snap.error}',
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              );
                                            }

                                            final docs = snap.data?.docs ?? [];

                                            final filtered = _q.isEmpty
                                                ? docs
                                                : docs.where((doc) {
                                                    final d = doc.data();
                                                    final haystack = [
                                                      _readString(
                                                          d, ['itemName']),
                                                      _readString(
                                                          d, ['stockInCode']),
                                                      _readString(
                                                          d, ['batchCode']),
                                                      _readString(d, [
                                                        'encodedByName'
                                                      ]),
                                                      _readString(d, [
                                                        'encodedByEmail'
                                                      ]),
                                                      _readString(d, ['type']),
                                                    ].join(' ').toLowerCase();

                                                    return haystack.contains(
                                                      _q.toLowerCase(),
                                                    );
                                                  }).toList();

                                            if (filtered.isEmpty) {
                                              return const Center(
                                                child: Text(
                                                  'No stock logs found.',
                                                  style: TextStyle(
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                              );
                                            }

                                            return ListView.separated(
                                              padding: const EdgeInsets.only(
                                                bottom: 16,
                                              ),
                                              itemCount: filtered.length,
                                              separatorBuilder: (_, __) =>
                                                  const SizedBox(height: 10),
                                              itemBuilder: (context, index) {
                                                final d =
                                                    filtered[index].data();

                                                final itemName = _readString(
                                                  d,
                                                  ['itemName'],
                                                  fallback: 'Unnamed Item',
                                                );
                                                final type = _readString(
                                                  d,
                                                  ['type'],
                                                  fallback: 'unknown',
                                                );
                                                final quantity = _readInt(
                                                  d,
                                                  ['quantity'],
                                                );
                                                final stockBefore = _readInt(
                                                  d,
                                                  ['stockBefore'],
                                                );
                                                final stockAfter = _readInt(
                                                  d,
                                                  ['stockAfter'],
                                                );
                                                final costPrice = _readDouble(
                                                  d,
                                                  ['costPrice', 'cost'],
                                                );
                                                final stockInCode = _readString(
                                                  d,
                                                  ['stockInCode'],
                                                );
                                                final batchCode = _readString(
                                                  d,
                                                  ['batchCode'],
                                                );
                                                final encodedByName =
                                                    _readString(
                                                  d,
                                                  ['encodedByName'],
                                                );
                                                final encodedByEmail =
                                                    _readString(
                                                  d,
                                                  ['encodedByEmail'],
                                                );
                                                final receivedDate = _readDate(
                                                  d,
                                                  ['receivedDate'],
                                                );
                                                final expiryDate = _readDate(
                                                  d,
                                                  ['expiryDate'],
                                                );
                                                final createdAt = _readDate(
                                                  d,
                                                  ['created_at'],
                                                );
                                                final notes = _readString(
                                                  d,
                                                  ['notes'],
                                                );

                                                final chipColor =
                                                    _typeColor(type);

                                                return Container(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.94),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.06),
                                                        blurRadius: 10,
                                                        offset:
                                                            const Offset(0, 3),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              itemName,
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Color(
                                                                    0xFF2F2F2F),
                                                              ),
                                                            ),
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 11,
                                                              vertical: 6,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: chipColor,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          16),
                                                            ),
                                                            child: Text(
                                                              type
                                                                  .replaceAll(
                                                                      '_', ' ')
                                                                  .toLowerCase(),
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 8,
                                                        children: [
                                                          _miniInfo(
                                                            'Qty',
                                                            '$quantity',
                                                          ),
                                                          _miniInfo(
                                                            'Before',
                                                            '$stockBefore',
                                                          ),
                                                          _miniInfo(
                                                            'After',
                                                            '$stockAfter',
                                                          ),
                                                          _miniInfo(
                                                            'Cost',
                                                            _money(costPrice),
                                                          ),
                                                          _miniInfo(
                                                            'Received',
                                                            _fmtDate(
                                                                receivedDate),
                                                          ),
                                                          _miniInfo(
                                                            'Expiry',
                                                            _fmtDate(
                                                                expiryDate),
                                                          ),
                                                          _miniInfo(
                                                            'Encoded',
                                                            _fmtTime(createdAt),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 10),
                                                      if (stockInCode.isNotEmpty)
                                                        Text(
                                                          'Stock In Code: $stockInCode',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12.5,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      if (batchCode.isNotEmpty)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(top: 2),
                                                          child: Text(
                                                            'Batch Code: $batchCode',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 12.5,
                                                            ),
                                                          ),
                                                        ),
                                                      if (encodedByName
                                                              .isNotEmpty ||
                                                          encodedByEmail
                                                              .isNotEmpty)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(top: 2),
                                                          child: Text(
                                                            'Encoded by: ${encodedByName.isEmpty ? '-' : encodedByName}${encodedByEmail.isEmpty ? '' : ' • $encodedByEmail'}',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 12.5,
                                                            ),
                                                          ),
                                                        ),
                                                      if (notes.isNotEmpty)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(top: 6),
                                                          child: Text(
                                                            'Notes: $notes',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .black54,
                                                            ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniInfo(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, color: Colors.black87),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}