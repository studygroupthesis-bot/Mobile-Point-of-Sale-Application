import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum InventoryMovementType {
  addStock,
  reduceStock,
  pullOutStock,
}

class StockMovementService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _typeKey(InventoryMovementType type) {
    switch (type) {
      case InventoryMovementType.addStock:
        return 'add_stock';
      case InventoryMovementType.reduceStock:
        return 'reduce_stock';
      case InventoryMovementType.pullOutStock:
        return 'pull_out_stock';
    }
  }

  int _deltaFor(InventoryMovementType type, int quantity) {
    switch (type) {
      case InventoryMovementType.addStock:
        return quantity;
      case InventoryMovementType.reduceStock:
        return -quantity;
      case InventoryMovementType.pullOutStock:
        return -quantity;
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> applyMovement({
    required String storeId,
    required InventoryMovementType type,
    required String itemId,
    required String itemName,
    required int quantity,
    String? note,
  }) async {
    if (quantity <= 0) {
      throw Exception('Quantity must be greater than zero.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final userSnap = await _db.collection('users').doc(user.uid).get();
    final userData = userSnap.data() ?? <String, dynamic>{};

    final createdByName =
        (userData['name'] ?? user.email ?? 'User').toString().trim();
    final createdByRole = (userData['role'] ?? '').toString().trim();

    final itemRef = _db
        .collection('stores')
        .doc(storeId)
        .collection('items')
        .doc(itemId);

    final logRef = _db
        .collection('stores')
        .doc(storeId)
        .collection('stock_logs')
        .doc();

    await _db.runTransaction((txn) async {
      final itemSnap = await txn.get(itemRef);

      if (!itemSnap.exists) {
        throw Exception('Item not found.');
      }

      final itemData = itemSnap.data() ?? <String, dynamic>{};
      final beforeQty = _toInt(itemData['stockQty']);
      final delta = _deltaFor(type, quantity);
      final afterQty = beforeQty + delta;

      if (afterQty < 0) {
        throw Exception(
          'Not enough stock. Current stock is $beforeQty.',
        );
      }

      txn.set(
        itemRef,
        {
          'stockQty': afterQty,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      txn.set(
        logRef,
        {
          'logId': logRef.id,
          'storeId': storeId,
          'itemId': itemId,
          'itemName': itemName,
          'type': _typeKey(type),
          'quantity': quantity,
          'delta': delta,
          'beforeQty': beforeQty,
          'afterQty': afterQty,
          'note': (note ?? '').trim(),
          'createdByUid': user.uid,
          'createdByName': createdByName,
          'createdByRole': createdByRole,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }
}