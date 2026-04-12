import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'add_edit_user_screen.dart';

class ManageUsersScreen extends StatelessWidget {
  const ManageUsersScreen({super.key});

  Future<String?> _getMyStoreId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    final data = userDoc.data();
    return data?['storeId'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDFF3EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFDFF3EF),
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          'Manage Users',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
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
        child: FutureBuilder<String?>(
          future: _getMyStoreId(),
          builder: (context, storeSnap) {
            if (storeSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final storeId = storeSnap.data;
            if (storeId == null || storeId.isEmpty) {
              return const Center(
                child: Text('Store not found for this user.'),
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Container(
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
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('stores')
                      .doc(storeId)
                      .collection('staff')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snap.hasError) {
                      return Center(
                        child: Text('Failed to load staff: ${snap.error}'),
                      );
                    }

                    final docs = snap.data?.docs ?? [];

                    return Column(
                      children: [
                        Expanded(
                          child: docs.isEmpty
                              ? const Center(
                                  child: Text('No staff found.'),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: docs.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final doc = docs[index];
                                    final data = doc.data();

                                    final name =
                                        (data['name'] as String?) ?? 'No name';
                                    final email =
                                        (data['email'] as String?) ?? 'No email';
                                    final role =
                                        (data['role'] as String?) ?? 'staff';
                                    final isActive =
                                        (data['isActive'] as bool?) ?? true;

                                    return Container(
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
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              const Color(0xFF2AA39A),
                                          child: Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '$email\nRole: $role${isActive ? '' : ' • Inactive'}',
                                        ),
                                        isThreeLine: true,
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AddEditUserScreen(
                                                storeId: storeId,
                                                staffUid: doc.id,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2AA39A),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddEditUserScreen(
                                      storeId: storeId,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.person_add,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'ADD USER',
                                style: TextStyle(color: Colors.white),
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
        ),
      ),
    );
  }
}