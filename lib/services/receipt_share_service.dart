import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiptShareResult {
  final String url;
  final String docPath;

  const ReceiptShareResult({
    required this.url,
    required this.docPath,
  });
}

class ReceiptShareService {
  ReceiptShareService._();

  static final ReceiptShareService instance = ReceiptShareService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<ReceiptShareResult> ensurePublicReceipt({
    required String storeId,
    required String transactionId,
    required Map<String, dynamic> transactionData,
  }) async {
    final publicRef = _db
        .collection('stores')
        .doc(storeId)
        .collection('public_receipts')
        .doc(transactionId);

    final transactionRef = _db
        .collection('stores')
        .doc(storeId)
        .collection('transactions')
        .doc(transactionId);

    final publicData = _buildPublicReceiptData(
      storeId: storeId,
      transactionId: transactionId,
      data: transactionData,
    );

    await publicRef.set(publicData, SetOptions(merge: true));

    final url = _buildPublicReceiptUrl(
      storeId: storeId,
      transactionId: transactionId,
    );

    await transactionRef.set({
      'publicReceiptUrl': url,
      'publicReceiptPath': publicRef.path,
      'publicReceiptEnabled': true,
      'publicReceiptUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return ReceiptShareResult(
      url: url,
      docPath: publicRef.path,
    );
  }

  Map<String, dynamic> _buildPublicReceiptData({
    required String storeId,
    required String transactionId,
    required Map<String, dynamic> data,
  }) {
    return {
      'storeId': storeId,
      'transactionId': transactionId,
      'invoiceId': (data['invoiceId'] ?? transactionId).toString(),
      'invoiceNo': (data['invoiceNo'] ?? data['receiptNumber'] ?? transactionId)
          .toString(),
      'receiptNumber':
          (data['receiptNumber'] ?? data['invoiceNo'] ?? transactionId)
              .toString(),
      'storeName': (data['storeName'] ?? 'Business Sale').toString(),
      'createdAt': data['createdAt'],
      'createdAtLocal': data['createdAtLocal'],
      'paymentMethod':
          (data['paymentMethod'] ?? data['paymentMode'] ?? 'Cash').toString(),
      'paymentMode':
          (data['paymentMode'] ?? data['paymentMethod'] ?? 'Cash').toString(),
      'subtotal': _safeToDouble(data['subtotal']),
      'taxableSales': _safeToDouble(
        data['taxableSales'],
        fallback: _safeToDouble(data['subtotal']),
      ),
      'taxEnabled': data['taxEnabled'] == true,
      'taxName': (data['taxName'] ?? 'VAT').toString(),
      'taxRate': _safeToDouble(data['taxRate'], fallback: 12.0),
      'taxInclusive': data['taxInclusive'] != false,
      'tax': _safeToDouble(
        data['tax'],
        fallback: _safeToDouble(data['taxAmount']),
      ),
      'grandTotal': _safeToDouble(
        data['grandTotal'],
        fallback: _safeToDouble(data['total']),
      ),
      'total': _safeToDouble(
        data['total'],
        fallback: _safeToDouble(data['grandTotal']),
      ),
      'amountReceived': _safeToDouble(
        data['amountReceived'],
        fallback: _safeToDouble(data['amountPaid']),
      ),
      'amountPaid': _safeToDouble(
        data['amountPaid'],
        fallback: _safeToDouble(data['amountReceived']),
      ),
      'change': _safeToDouble(data['change']),
      'items': _sanitizeItems(data['items']),
      'status': (data['status'] ?? 'Success').toString(),
      'isActive': true,
      'sharedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  List<Map<String, dynamic>> _sanitizeItems(dynamic rawItems) {
    if (rawItems is! List) return const [];

    return rawItems.map<Map<String, dynamic>>((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return {
        'itemId': map['itemId']?.toString(),
        'name': (map['name'] ?? '').toString(),
        'barcode': map['barcode']?.toString(),
        'price': _safeToDouble(map['price']),
        'qty': _safeToInt(map['qty']),
        'total': _safeToDouble(
          map['total'],
          fallback: _safeToDouble(map['price']) * _safeToInt(map['qty']),
        ),
      };
    }).toList();
  }

  String _buildPublicReceiptUrl({
    required String storeId,
    required String transactionId,
  }) {
    final origin = Uri.base.origin;
    return '$origin/#/public-receipt?storeId='
        '${Uri.encodeComponent(storeId)}&transactionId='
        '${Uri.encodeComponent(transactionId)}';
  }

  double _safeToDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _safeToInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }
}
