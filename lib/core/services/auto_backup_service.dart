import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/backup_utils.dart';
import 'firestore_service.dart';

class AutoBackupService {
  static AutoBackupService? _instance;
  static AutoBackupService get instance => _instance ??= AutoBackupService._();
  AutoBackupService._();

  static const _lastBackupKey = 'last_auto_backup_ms';

  bool _running = false;

  Future<void> triggerBackup(String uid, {bool force = false}) async {
    if (_running) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!force) {
        final lastBackup = prefs.getInt(_lastBackupKey) ?? 0;
        final elapsed = DateTime.now().millisecondsSinceEpoch - lastBackup;
        // Debounce automatic backups to at most once every 6 hours
        if (elapsed < const Duration(hours: 6).inMilliseconds) return;
      }
      _running = true;

      final fs = FirestoreService(uid: uid);
      final collections = {
        'students': fs.studentsCol,
        'staff': fs.staffCol,
        'seats': fs.seatsCol,
        'seat_layouts': fs.seatLayoutsCol,
        'attendance': fs.attendanceCol,
        'fees': fs.feesCol,
        'books': fs.booksCol,
        'book_transactions': fs.bookTransactionsCol,
        'notifications': fs.notificationsCol,
        'libraries': fs.librariesCol,
        'activities': fs.activitiesCol,
        'expenses': fs.expensesCol,
        'notices': fs.noticesCol,
      };

      final backupData = <String, List<Map<String, dynamic>>>{};
      int totalEstimatedBytes = 0;
      for (final entry in collections.entries) {
        try {
          final snap = await entry.value.get();
          final items = snap.docs.map((d) => d.data()).toList();
          backupData[entry.key] = items;
          totalEstimatedBytes += jsonEncode(items).length;
        } catch (_) {
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final latestDocRef = fs.firestore
          .collection('users')
          .doc(uid)
          .collection('backups')
          .doc('latest');
      final timeDocRef = fs.firestore
          .collection('users')
          .doc(uid)
          .collection('backups')
          .doc('auto_$timestamp');

      // Firestore document hard limit is 1 MiB (1,048,576 bytes).
      // If estimated size exceeds 750 KB, store per-collection chunks to avoid
      // "Document exceeds maximum allowed size" failures.
      final isChunked = totalEstimatedBytes > 750000;

      if (!isChunked) {
        final payload = {
          'version': '2.0',
          'isChunked': false,
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': timestamp,
          'data': backupData,
        };
        final batch = fs.firestore.batch();
        batch.set(latestDocRef, payload);
        batch.set(timeDocRef, payload);
        await batch.commit();
      } else {
        final metaPayload = {
          'version': '2.0',
          'isChunked': true,
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': timestamp,
          'collections': backupData.keys.toList(),
        };
        final batch = fs.firestore.batch();
        batch.set(latestDocRef, metaPayload);
        batch.set(timeDocRef, metaPayload);
        await batch.commit();

        for (final entry in backupData.entries) {
          final items = entry.value;
          final colDocLatest = latestDocRef.collection('collections').doc(entry.key);
          final colDocTime = timeDocRef.collection('collections').doc(entry.key);
          await colDocLatest.set({'items': items});
          await colDocTime.set({'items': items});
        }
      }

      await prefs.setInt(_lastBackupKey, timestamp);
    } catch (_) {
    } finally {
      _running = false;
    }
  }

  Future<bool> restoreLatestBackup(String uid) async {
    try {
      final latestDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('backups')
          .doc('latest')
          .get();

      DocumentSnapshot<Map<String, dynamic>>? targetDoc;
      if (latestDoc.exists && latestDoc.data() != null) {
        targetDoc = latestDoc;
      } else {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('backups')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (snap.docs.isNotEmpty) {
          targetDoc = snap.docs.first;
        }
      }

      if (targetDoc == null) return false;

      final Map<String, List<dynamic>> backupData = {};
      final isChunked = targetDoc.data()?['isChunked'] == true;

      if (isChunked) {
        final colSnaps = await targetDoc.reference.collection('collections').get();
        for (final doc in colSnaps.docs) {
          final items = doc.data()['items'] as List<dynamic>? ?? [];
          backupData[doc.id] = items;
        }
      } else {
        final rawData = targetDoc.data()?['data'] as Map<String, dynamic>?;
        if (rawData != null) {
          for (final entry in rawData.entries) {
            backupData[entry.key] = (entry.value as List<dynamic>? ?? []);
          }
        }
      }

      if (backupData.isEmpty) return false;

      for (final entry in backupData.entries) {
        final collectionName = entry.key;
        final items = entry.value;
        if (items.isEmpty) continue;

        final col = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection(collectionName);

        for (int i = 0; i < items.length; i += 500) {
          final batch = FirebaseFirestore.instance.batch();
          final chunk = items.skip(i).take(500);
          int itemIdx = 0;
          for (final item in chunk) {
            final map = Map<String, dynamic>.from(item as Map);
            final docId = pickBackupDocId(collectionName, map, i + itemIdx);
            batch.set(col.doc(docId.toString()), map, SetOptions(merge: true));
            itemIdx++;
          }
          await batch.commit();
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
