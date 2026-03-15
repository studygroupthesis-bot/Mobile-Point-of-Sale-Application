import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class ReceiptShareResult {
  final String token;
  final String url;

  const ReceiptShareResult({
    required this.token,
    required this.url,
  });
}

class ReceiptShareService {
  ReceiptShareService._();

  static final ReceiptShareService instance = ReceiptShareService._();
  static const Uuid _uuid = Uuid();

  static const String receiptBaseUrl =
      'https://fi-pos-system.web.app/#/receipt';

  Future<ReceiptShareResult> ensurePublicReceipt({
    required String storeId,
    required String transactionId,
    required Map<String, dynamic> transactionData,
  }) async {
    final txRef = FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('transactions')
        .doc(transactionId);

    final existingToken = (transactionData['receiptToken'] as String?)?.trim();
    final existingUrl =
        (transactionData['publicReceiptUrl'] as String?)?.trim();

    if (existingToken != null && existingToken.isNotEmpty) {
      return ReceiptShareResult(
        token: existingToken,
        url: (existingUrl != null && existingUrl.isNotEmpty)
            ? existingUrl
            : _buildReceiptUrl(existingToken),
      );
    }

    final token = _uuid.v4().replaceAll('-', '');
    final url = _buildReceiptUrl(token);

    final publicReceipt = <String, dynamic>{
      'token': token,
      'storeId': storeId,
      'transactionId': transactionId,
      'receiptNumber': transactionData['receiptNumber'] ??
          transactionData['invoiceNo'] ??
          transactionId,
      'storeName': transactionData['storeName'] ?? '',
      'cashierName':
          transactionData['cashierName'] ?? transactionData['cashierUid'] ?? '',
      'paymentMethod': transactionData['paymentMethod'] ??
          transactionData['paymentMode'] ??
          'Cash',
      'subtotal': _toDouble(transactionData['subtotal']),
      'discount': _toDouble(transactionData['discount']),
      'tax': _toDouble(transactionData['tax']),
      'total': _toDouble(
        transactionData['total'] ?? transactionData['grandTotal'],
      ),
      'amountPaid': _toDouble(
        transactionData['amountPaid'] ?? transactionData['amountReceived'],
      ),
      'change': _toDouble(transactionData['change']),
      'items': _sanitizeItems(transactionData['items']),
      'createdAt': transactionData['createdAt'] ?? FieldValue.serverTimestamp(),
      'createdAtLocal': transactionData['createdAtLocal'],
      'sharedAt': FieldValue.serverTimestamp(),
      'isActive': true,
    };

    await FirebaseFirestore.instance
        .collection('public_receipts')
        .doc(token)
        .set(publicReceipt);

    await txRef.update({
      'receiptToken': token,
      'publicReceiptUrl': url,
      'receiptSharedAt': FieldValue.serverTimestamp(),
    });

    return ReceiptShareResult(token: token, url: url);
  }

  String _buildReceiptUrl(String token) {
    return '$receiptBaseUrl?token=${Uri.encodeQueryComponent(token)}';
  }

  List<Map<String, dynamic>> _sanitizeItems(dynamic rawItems) {
    if (rawItems is! List) return [];

    return rawItems.map<Map<String, dynamic>>((item) {
      final map =
          item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};

      final qty = _toInt(map['qty']);
      final price = _toDouble(map['price']);
      final lineTotal = _toDouble(
        map['total'] ?? map['lineTotal'] ?? (qty * price),
      );

      return {
        'name': map['name'] ?? '',
        'barcode': map['barcode'] ?? '',
        'qty': qty,
        'price': price,
        'total': lineTotal,
      };
    }).toList();
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
