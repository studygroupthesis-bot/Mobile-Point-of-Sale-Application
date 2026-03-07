import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '/firebase/firebase_options.dart';

class StoreMembersService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String?> getMyStoreId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    return data?['storeId'] as String?;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMembers(String storeId) {
    return _db
        .collection('stores')
        .doc(storeId)
        .collection('members')
        .orderBy('name')
        .snapshots();
  }

  /// ✅ Admin creates staff auth account WITHOUT logging out admin (secondary app)
  Future<void> createStaff({
    required String storeId,
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role, // "staff" or "admin"
    required Map<String, dynamic> permissions, 
  }) async {
    // Create / reuse secondary Firebase app
    FirebaseApp secondary;
    try {
      secondary = Firebase.app('secondary');
    } catch (_) {
      secondary = await Firebase.initializeApp(
        name: 'secondary',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final secondaryAuth = FirebaseAuth.instanceFor(app: secondary);

    // Create auth user on secondary auth
    final cred = await secondaryAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final newUid = cred.user!.uid;

    // Sign out secondary (keeps admin session intact)
    await secondaryAuth.signOut();

    final now = FieldValue.serverTimestamp();

    // 1) user profile doc (global)
    await _db.collection('users').doc(newUid).set({
      'uid': newUid,
      'storeId': storeId,
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'role': role,
      'permissions':permissions,
      'isActive': true, 
      'created_at': now,
      'updated_at': now,
    }, SetOptions(merge: true));

    // 2) store members list (for fast querying per store)
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('members')
        .doc(newUid)
        .set({
      'uid': newUid,
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'role': role,
      'permissions': permissions,
      'isActive': true, 
      'created_at': now,
      'updated_at': now,
    }, SetOptions(merge: true));
  }

  Future<void> updateMember({
    required String storeId,
    required String uid,
    required String name,
    required String phone,
    required String role,
    required Map<String, dynamic> permissions, 
  }) async {
    final now = FieldValue.serverTimestamp();

    // Update store member
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('members')
        .doc(uid)
        .set({
      'name': name.trim(),
      'phone': phone.trim(),
      'role': role,
      'permissions': permissions, 
      'updated_at': now,
    }, SetOptions(merge: true));

    // Keep users doc in sync
    await _db.collection('users').doc(uid).set({
      'name': name.trim(),
      'phone': phone.trim(),
      'role': role,
      'permissions': permissions,
      'updated_at': now,
    }, SetOptions(merge: true));
  }

  Future<void> deleteMember({
    required String storeId,
    required String uid,
  }) async {
    // NOTE: This removes Firestore membership only.
    // Deleting FirebaseAuth user requires Admin SDK / Cloud Function.
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('members')
        .doc(uid)
        .delete();
  }
}
