import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '/firebase/firebase_options.dart';

class StoreStaffService {
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
        .collection('staff')
        .orderBy('name')
        .snapshots();
  }

  Future<void> createStaff({
    required String storeId,
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
    required Map<String, dynamic> permissions,
  }) async {
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

    final cred = await secondaryAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final newUser = cred.user;
    if (newUser == null) {
      throw Exception('Failed to create staff account.');
    }

    final newUid = newUser.uid;

    await newUser.sendEmailVerification();
    await secondaryAuth.signOut();

    final now = FieldValue.serverTimestamp();

    await _db.collection('users').doc(newUid).set({
      'uid': newUid,
      'storeId': storeId,
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'role': role,
      'permissions': permissions,
      'isActive': true,
      'mustChangePassword': true,
      'passwordLastChangedAt': now,
      'created_at': now,
      'updated_at': now,
    }, SetOptions(merge: true));

    await _db
        .collection('stores')
        .doc(storeId)
        .collection('staff')
        .doc(newUid)
        .set({
      'uid': newUid,
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'role': role,
      'permissions': permissions,
      'isActive': true,
      'mustChangePassword': true,
      'passwordLastChangedAt': now,
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
    required bool isActive,
    required bool mustChangePassword,
  }) async {
    final now = FieldValue.serverTimestamp();

    final updateData = {
      'name': name.trim(),
      'phone': phone.trim(),
      'role': role,
      'permissions': permissions,
      'isActive': isActive,
      'mustChangePassword': mustChangePassword,
      'updated_at': now,
    };

    await _db
        .collection('stores')
        .doc(storeId)
        .collection('staff')
        .doc(uid)
        .set(updateData, SetOptions(merge: true));

    await _db
        .collection('users')
        .doc(uid)
        .set(updateData, SetOptions(merge: true));
  }

  Future<void> setMemberActiveStatus({
    required String storeId,
    required String uid,
    required bool isActive,
  }) async {
    final now = FieldValue.serverTimestamp();

    await _db
        .collection('stores')
        .doc(storeId)
        .collection('staff')
        .doc(uid)
        .set({
      'isActive': isActive,
      'updated_at': now,
    }, SetOptions(merge: true));

    await _db.collection('users').doc(uid).set({
      'isActive': isActive,
      'updated_at': now,
    }, SetOptions(merge: true));
  }

  Future<void> forcePasswordReset({
    required String storeId,
    required String uid,
  }) async {
    final now = FieldValue.serverTimestamp();

    await _db
        .collection('stores')
        .doc(storeId)
        .collection('staff')
        .doc(uid)
        .set({
      'mustChangePassword': true,
      'updated_at': now,
    }, SetOptions(merge: true));

    await _db.collection('users').doc(uid).set({
      'mustChangePassword': true,
      'updated_at': now,
    }, SetOptions(merge: true));
  }

  Future<void> deactivateMember({
    required String storeId,
    required String uid,
  }) async {
    await setMemberActiveStatus(
      storeId: storeId,
      uid: uid,
      isActive: false,
    );
  }

  Future<void> activateMember({
    required String storeId,
    required String uid,
  }) async {
    await setMemberActiveStatus(
      storeId: storeId,
      uid: uid,
      isActive: true,
    );
  }

  Future<void> deleteMember({
    required String storeId,
    required String uid,
  }) async {
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('staff')
        .doc(uid)
        .delete();
  }
}