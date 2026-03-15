import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../firebase/store_staff_services.dart';
import 'manage_user_form_screen.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _svc = StoreMembersService();
  final _searchCtrl = TextEditingController();

  String? _storeId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadStoreId();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStoreId() async {
    final id = await _svc.getMyStoreId();
    if (!mounted) return;
    setState(() => _storeId = id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE79A9A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title:
            const Text('Manage Users', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: _storeId == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    // Search bar (no avatar header)
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search user...',
                        suffixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _svc.streamMembers(_storeId!),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Center(
                              child: Text('Error: ${snap.error}'),
                            );
                          }
                          if (!snap.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final docs = snap.data!.docs;

                          // filter by search
                          final filtered = docs.where((d) {
                            final data = d.data();
                            final name =
                                (data['name'] as String? ?? '').toLowerCase();
                            final email =
                                (data['email'] as String? ?? '').toLowerCase();
                            return _query.isEmpty ||
                                name.contains(_query) ||
                                email.contains(_query);
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(
                              child: Text(
                                'No users yet.\nTap ADD USER to create staff.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final doc = filtered[i];
                              final data = doc.data();

                              final uid = data['uid'] as String? ?? doc.id;
                              final name = data['name'] as String? ?? 'No name';
                              final email = data['email'] as String? ?? '';
                              final role = data['role'] as String? ?? 'staff';

                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddEditUserScreen(
                                        storeId: _storeId!,
                                        memberUid: uid,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      const CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Colors.white,
                                        child: Icon(Icons.person,
                                            color: Colors.black54),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(name,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            const SizedBox(height: 2),
                                            Text(email,
                                                style: const TextStyle(
                                                    color: Colors.black54,
                                                    fontSize: 12)),
                                            const SizedBox(height: 2),
                                            Text('Role: $role',
                                                style: const TextStyle(
                                                    color: Colors.black54,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2AA39A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddEditUserScreen(storeId: _storeId!),
                            ),
                          );
                        },
                        child: const Text('ADD USER',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
