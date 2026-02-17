import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DataSyncScreen extends StatefulWidget {
  const DataSyncScreen({super.key});

  @override
  State<DataSyncScreen> createState() => _DataSyncScreenState();
}

class _DataSyncScreenState extends State<DataSyncScreen> {
  bool _initialized = false;
  bool _saving = false;
  bool _syncingNow = false;

  // Settings (stored in stores/{storeId})
  bool _autoSync = false;
  String _syncFrequency = 'manual'; // hourly/daily/monthly/manual
  bool _excludeArchivedOrders = false;
  bool _showLastSyncTimestamp = true;
  bool _includeTransactionPhotos = false;

  DateTime? _lastSyncAt;

  String _relativeTime(DateTime? dt) {
    if (dt == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 10) return 'Just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _saveChanges(String storeId) async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('stores').doc(storeId).set({
        'sync_auto': _autoSync,
        'sync_frequency': _syncFrequency,
        'sync_exclude_archived_orders': _excludeArchivedOrders,
        'sync_show_last_sync_timestamp': _showLastSyncTimestamp,
        'sync_include_transaction_photos': _includeTransactionPhotos,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync settings saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _syncNow(String storeId) async {
    setState(() => _syncingNow = true);
    try {
      // “Sync Now” is just a safe server timestamp marker for now.
      // Later, this is where you trigger actual syncing logic.
      await FirebaseFirestore.instance.collection('stores').doc(storeId).set({
        'last_sync_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Synced successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _syncingNow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFE79A9A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text('Data Sync', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: uid == null
          ? const Center(child: Text('Not logged in.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, userSnap) {
                final userData = userSnap.data?.data() ?? {};
                final storeId = userData['storeId'] as String?;

                if (storeId == null || storeId.isEmpty) {
                  return const Center(
                      child: Text('No store linked to account.'));
                }

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('stores')
                      .doc(storeId)
                      .snapshots(),
                  builder: (context, storeSnap) {
                    final storeData = storeSnap.data?.data() ?? {};

                    // Read from Firestore (with defaults)
                    final autoSync = (storeData['sync_auto'] as bool?) ?? false;
                    final freq =
                        (storeData['sync_frequency'] as String?) ?? 'manual';
                    final excludeArchived =
                        (storeData['sync_exclude_archived_orders'] as bool?) ??
                            false;
                    final showStamp =
                        (storeData['sync_show_last_sync_timestamp'] as bool?) ??
                            true;
                    final includePhotos =
                        (storeData['sync_include_transaction_photos']
                                as bool?) ??
                            false;

                    final lastSyncTs = storeData['last_sync_at'];
                    DateTime? lastSyncAt;
                    if (lastSyncTs is Timestamp) {
                      lastSyncAt = lastSyncTs.toDate();
                    }

                    // Initialize ONCE so the UI doesn’t reset while editing
                    if (!_initialized) {
                      _autoSync = autoSync;
                      _syncFrequency = freq;
                      _excludeArchivedOrders = excludeArchived;
                      _showLastSyncTimestamp = showStamp;
                      _includeTransactionPhotos = includePhotos;
                      _lastSyncAt = lastSyncAt;
                      _initialized = true;
                    } else {
                      // keep last sync reactive
                      _lastSyncAt = lastSyncAt;
                    }

                    final syncedLabel = _lastSyncAt == null
                        ? 'Not yet synced'
                        : 'Data is Synced';

                    return Center(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              leading: Icon(
                                _lastSyncAt == null
                                    ? Icons.info
                                    : Icons.check_circle,
                                color: _lastSyncAt == null
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                              title: Text(syncedLabel),
                              subtitle: Text(
                                'Last Sync: ${_relativeTime(_lastSyncAt)}',
                              ),
                              trailing: TextButton(
                                onPressed: (_saving || _syncingNow)
                                    ? null
                                    : () => _syncNow(storeId),
                                child: Text(
                                    _syncingNow ? 'SYNCING...' : 'Sync Now'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SwitchListTile(
                              title: const Text('Auto-Sync'),
                              value: _autoSync,
                              onChanged: (_saving || _syncingNow)
                                  ? null
                                  : (v) => setState(() => _autoSync = v),
                            ),
                            DropdownButtonFormField<String>(
                              initialValue: _syncFrequency,
                              decoration: const InputDecoration(
                                  labelText: 'Sync Frequency'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'hourly', child: Text('Hourly')),
                                DropdownMenuItem(
                                    value: 'daily', child: Text('Daily')),
                                DropdownMenuItem(
                                    value: 'monthly', child: Text('Monthly')),
                                DropdownMenuItem(
                                    value: 'manual', child: Text('Manual')),
                              ],
                              onChanged: (_saving || _syncingNow)
                                  ? null
                                  : (v) {
                                      if (v == null) return;
                                      setState(() => _syncFrequency = v);
                                    },
                            ),
                            const SizedBox(height: 10),
                            CheckboxListTile(
                              value: _excludeArchivedOrders,
                              onChanged: (_saving || _syncingNow)
                                  ? null
                                  : (v) => setState(() =>
                                      _excludeArchivedOrders = v ?? false),
                              title: const Text('Exclude archived orders'),
                            ),
                            CheckboxListTile(
                              value: _showLastSyncTimestamp,
                              onChanged: (_saving || _syncingNow)
                                  ? null
                                  : (v) => setState(
                                      () => _showLastSyncTimestamp = v ?? true),
                              title: const Text('Last Sync Time Stamp'),
                            ),
                            CheckboxListTile(
                              value: _includeTransactionPhotos,
                              onChanged: (_saving || _syncingNow)
                                  ? null
                                  : (v) => setState(() =>
                                      _includeTransactionPhotos = v ?? false),
                              title: const Text('Include Transaction Photos'),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                onPressed: (_saving || _syncingNow)
                                    ? null
                                    : () => _saveChanges(storeId),
                                child: Text(
                                    _saving ? 'SAVING...' : 'SAVE CHANGES'),
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
    );
  }
}
