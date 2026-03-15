import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StockLogsScreen extends StatefulWidget {
  const StockLogsScreen({super.key});

  @override
  State<StockLogsScreen> createState() => _StockLogsScreenState();
}

class _StockLogsScreenState extends State<StockLogsScreen> {
  final _search = TextEditingController();
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
    if (user == null) throw Exception("Not logged in.");

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final storeId = snap.data()?['storeId'] as String?;
    if (storeId == null || storeId.isEmpty) {
      throw Exception("Missing storeId in users/${user.uid}.");
    }
    return storeId;
  }

  Future<bool> _isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final role = (snap.data()?['role'] ?? '').toString().toLowerCase();
    return role == 'admin';
  }

  int _readInt(Map<String, dynamic> d, List<String> keys, {int fallback = 0}) {
    for (final k in keys) {
      final v = d[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return p;
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
        final p = double.tryParse(v);
        if (p != null) return p;
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
      body: SafeArea(
        child: FutureBuilder<bool>(
          future: _isAdminFuture,
          builder: (context, adminSnap) {
            if (adminSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (adminSnap.data != true) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Admin only.\nYou do not have permission to view Stock Logs.',
                    textAlign: TextAlign.center,
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
                  return Center(
                    child: Text(
                      'Failed to load store.\n${storeSnap.error ?? ''}',
                      textAlign: TextAlign.center,
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

                return Center(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFE6F7F5),
                          Color(0xFFD5F0EC),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back_ios_new),
                            ),
                            const Expanded(
                              child: Text(
                                'Stock Logs',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _search,
                          onChanged: (v) => setState(() => _q = v.trim()),
                          decoration: InputDecoration(
                            hintText: 'Search product / code / encoder...',
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>>(
                            stream: logsStream,
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (snap.hasError) {
                                return Center(
                                  child: Text(
                                    'Failed to load stock logs.\n${snap.error}',
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }

                              final docs = snap.data?.docs ?? [];

                              final filtered = _q.isEmpty
                                  ? docs
                                  : docs.where((doc) {
                                      final d = doc.data();
                                      final haystack = [
                                        _readString(d, ['itemName']),
                                        _readString(d, ['stockInCode']),
                                        _readString(d, ['batchCode']),
                                        _readString(d, ['encodedByName']),
                                        _readString(d, ['encodedByEmail']),
                                        _readString(d, ['type']),
                                      ].join(' ').toLowerCase();

                                      return haystack
                                          .contains(_q.toLowerCase());
                                    }).toList();

                              if (filtered.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No stock logs found.',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                );
                              }

                              return ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final d = filtered[index].data();

                                  final itemName = _readString(d, ['itemName'],
                                      fallback: 'Unnamed Item');
                                  final type = _readString(d, ['type'],
                                      fallback: 'unknown');
                                  final quantity = _readInt(d, ['quantity']);
                                  final stockBefore =
                                      _readInt(d, ['stockBefore']);
                                  final stockAfter =
                                      _readInt(d, ['stockAfter']);
                                  final costPrice =
                                      _readDouble(d, ['costPrice', 'cost']);
                                  final stockInCode =
                                      _readString(d, ['stockInCode']);
                                  final batchCode =
                                      _readString(d, ['batchCode']);
                                  final encodedByName =
                                      _readString(d, ['encodedByName']);
                                  final encodedByEmail =
                                      _readString(d, ['encodedByEmail']);
                                  final receivedDate =
                                      _readDate(d, ['receivedDate']);
                                  final expiryDate =
                                      _readDate(d, ['expiryDate']);
                                  final createdAt =
                                      _readDate(d, ['created_at']);
                                  final notes = _readString(d, ['notes']);

                                  final chipColor = _typeColor(type);

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.92),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
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
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: chipColor,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Text(
                                                type.replaceAll('_', ' '),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
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
                                              _fmtDate(receivedDate),
                                            ),
                                            _miniInfo(
                                              'Expiry',
                                              _fmtDate(expiryDate),
                                            ),
                                            _miniInfo(
                                              'Encoded',
                                              _fmtTime(createdAt),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        if (stockInCode.isNotEmpty)
                                          Text(
                                            'Stock In Code: $stockInCode',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        if (batchCode.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Batch Code: $batchCode',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        if (encodedByName.isNotEmpty ||
                                            encodedByEmail.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Encoded by: ${encodedByName.isEmpty ? '-' : encodedByName}${encodedByEmail.isEmpty ? '' : ' • $encodedByEmail'}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        if (notes.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 6),
                                            child: Text(
                                              'Notes: $notes',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
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
                );
              },
            );
          },
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
