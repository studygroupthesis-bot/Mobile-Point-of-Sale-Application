import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final String? storeId;
  final String? storeName;
  final bool showBackButton;

  const TransactionHistoryScreen({
    super.key,
    this.storeId,
    this.storeName,
    this.showBackButton = true,
  });

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  static const Color _pinkBg = Color(0xFFD98E93);
  static const Color _pageBg = Color(0xFFDFF1EF);
  static const Color _cardBg = Color(0xFFF8F8F8);
  static const Color _teal = Color(0xFF157A7E);
  static const Color _softTeal = Color(0xFFCDE8E4);
  static const Color _mutedText = Color(0xFF8B8B8B);
  static const Color _success = Color(0xFF1E8D79);

  bool _loading = true;
  String? _storeId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadStoreContext();
  }

  Future<void> _loadStoreContext() async {
    try {
      if (widget.storeId != null && widget.storeId!.trim().isNotEmpty) {
        setState(() {
          _storeId = widget.storeId!.trim();
          _loading = false;
        });
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Not logged in.');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data() ?? {};
      final resolvedStoreId = (data['storeId'] as String?)?.trim();

      if (resolvedStoreId == null || resolvedStoreId.isEmpty) {
        throw Exception('No storeId found.');
      }

      if (!mounted) return;

      setState(() {
        _storeId = resolvedStoreId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load transaction history: $e')),
      );
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();

    final cleaned = value
        .toString()
        .replaceAll('₱', '')
        .replaceAll(',', '')
        .trim();

    return double.tryParse(cleaned) ?? 0;
  }

  DateTime? _extractDate(Map<String, dynamic> data) {
    final possibleValues = [
      data['createdAt'],
      data['timestamp'],
      data['transactionDate'],
      data['dateCreated'],
      data['paidAt'],
      data['time'],
      data['date'],
    ];

    for (final value in possibleValues) {
      if (value == null) continue;

      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;

      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) return parsed;
      }

      if (value is int) {
        try {
          return DateTime.fromMillisecondsSinceEpoch(value);
        } catch (_) {}
      }
    }

    return null;
  }

  String _extractInvoiceNumber(String docId, Map<String, dynamic> data) {
    final invoice = [
      data['invoiceNumber'],
      data['invoiceNo'],
      data['receiptNumber'],
      data['referenceNo'],
      data['referenceNumber'],
      data['transactionId'],
      data['transactionNumber'],
      data['orderNumber'],
    ].firstWhere(
      (value) => value != null && value.toString().trim().isNotEmpty,
      orElse: () => '',
    );

    if (invoice.toString().trim().isNotEmpty) {
      return invoice.toString().trim();
    }

    return docId;
  }

  String _extractPaymentMethod(Map<String, dynamic> data) {
    final paymentMethod = [
      data['paymentMethod'],
      data['modeOfPayment'],
      data['paymentType'],
      data['tenderType'],
      data['method'],
    ].firstWhere(
      (value) => value != null && value.toString().trim().isNotEmpty,
      orElse: () => 'Cash',
    );

    return paymentMethod.toString().trim();
  }

  String _extractStatus(Map<String, dynamic> data) {
    final status = [
      data['status'],
      data['paymentStatus'],
      data['transactionStatus'],
    ].firstWhere(
      (value) => value != null && value.toString().trim().isNotEmpty,
      orElse: () => 'Success',
    );

    final text = status.toString().trim();
    if (text.isEmpty) return 'Success';

    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  double _extractTotal(Map<String, dynamic> data) {
    final total = [
      data['grandTotal'],
      data['totalAmount'],
      data['finalTotal'],
      data['amountPaid'],
      data['total'],
      data['subtotal'],
    ].firstWhere(
      (value) => value != null,
      orElse: () => 0,
    );

    return _toDouble(total);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _formatShortDate(DateTime date) {
    final yy = (date.year % 100).toString().padLeft(2, '0');
    return '${_twoDigits(date.month)}/${_twoDigits(date.day)}/$yy';
  }

  String _formatPeso(double amount) {
    return '₱ ${amount.toStringAsFixed(2)}';
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '--:--';

    int hour = date.hour;
    final minute = _twoDigits(date.minute);
    final suffix = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '$hour:$minute $suffix';
  }

  String _salesLabel() {
    final today = DateTime.now();

    if (_isSameDate(today, _selectedDate)) {
      return "Today's Sales";
    }

    return 'Sales on ${_formatShortDate(_selectedDate)}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _teal,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
    });
  }

  Widget _buildHeader() {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: widget.showBackButton
              ? IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.chevron_left),
                  color: Colors.black87,
                )
              : const SizedBox.shrink(),
        ),
        const Expanded(
          child: Text(
            'Transaction History',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }

  Widget _buildSalesCard(double totalSales) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _salesLabel(),
            style: const TextStyle(
              fontSize: 12,
              color: _mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatPeso(totalSales),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Text(
            'Transaction History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _teal,
            ),
          ),
        ),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFE6E6E6),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatShortDate(_selectedDate),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 38,
            color: Colors.black38,
          ),
          SizedBox(height: 10),
          Text(
            'No transactions found for this date.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard({
    required String invoiceNumber,
    required String paymentMethod,
    required DateTime? date,
    required double total,
    required String status,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: _softTeal,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: _teal,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice #$invoiceNumber',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  paymentMethod,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatPeso(total),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatTime(date),
                style: const TextStyle(
                  fontSize: 10,
                  color: _mutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                status,
                style: const TextStyle(
                  fontSize: 11,
                  color: _success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterAndSortDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final filtered = docs.where((doc) {
      final data = doc.data();
      final date = _extractDate(data);
      if (date == null) return false;
      return _isSameDate(date, _selectedDate);
    }).toList();

    filtered.sort((a, b) {
      final aDate =
          _extractDate(a.data()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          _extractDate(b.data()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  double _computeSelectedDateSales(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    double total = 0;

    for (final doc in docs) {
      total += _extractTotal(doc.data());
    }

    return total;
  }

  Widget _buildContent() {
    final storeId = _storeId;

    if (storeId == null || storeId.isEmpty) {
      return const Center(
        child: Text(
          'No store found.',
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('transactions')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Failed to load transactions.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data!.docs;
        final filteredDocs = _filterAndSortDocs(allDocs);
        final totalSales = _computeSelectedDateSales(filteredDocs);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildSalesCard(totalSales),
            const SizedBox(height: 18),
            _buildSectionHeader(),
            const SizedBox(height: 12),
            Expanded(
              child: filteredDocs.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: filteredDocs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data();

                        return _buildTransactionCard(
                          invoiceNumber: _extractInvoiceNumber(doc.id, data),
                          paymentMethod: _extractPaymentMethod(data),
                          date: _extractDate(data),
                          total: _extractTotal(data),
                          status: _extractStatus(data),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pinkBg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 74),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  decoration: BoxDecoration(
                    color: _pageBg,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: _buildContent(),
                ),
              ),
      ),
    );
  }
}