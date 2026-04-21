import 'package:cloud_firestore/cloud_firestore.dart';

class StoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> createStoreForOwner({
    required String ownerUid,
    required String email,
    required String ownerName,
    required String businessName,
  }) async {
    final storeRef = _db.collection('stores').doc();

    await storeRef.set({
      'storeId': storeRef.id,
      'ownerUid': ownerUid,
      'business_name': businessName,
      'address': '',
      'accept_cash': true,
      'accept_gcash': false,
      'logo_url': '',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _db.collection('users').doc(ownerUid).set({
      'uid': ownerUid,
      'email': email,
      'name': ownerName,
      'role': 'admin',
      'storeId': storeRef.id,
      'phone': '',
      'isActive': true,
      'mustChangePassword': false,
      'passwordLastChangedAt': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return storeRef.id;
  }
}