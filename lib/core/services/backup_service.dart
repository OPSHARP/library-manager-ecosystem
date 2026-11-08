import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/backup_utils.dart';

class BackupService {
  static BackupService? _instance;
  static BackupService get instance => _instance ??= BackupService._();
  BackupService._();

  /// Export all data for the given [uid] from Firestore to a JSON file.
  Future<String> exportBackup(String uid) async {
    try {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

    final results = await Future.wait([
      userDoc.collection('students').get(),
      userDoc.collection('staff').get(),
      userDoc.collection('seats').get(),
      userDoc.collection('libraries').get(),
      userDoc.collection('attendance').get(),
      userDoc.collection('fees').get(),
      userDoc.collection('books').get(),
      userDoc.collection('book_transactions').get(),
      userDoc.collection('notifications').get(),
      userDoc.collection('seat_layouts').get(),
    ]);

    final backup = {
      'version': '2.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'uid': uid,
      'data': {
        'students': results[0].docs.map((d) => d.data()).toList(),
        'staff': results[1].docs.map((d) => d.data()).toList(),
        'seats': results[2].docs.map((d) => d.data()).toList(),
        'libraries': results[3].docs.map((d) => d.data()).toList(),
        'attendance': results[4].docs.map((d) => d.data()).toList(),
        'fees': results[5].docs.map((d) => d.data()).toList(),
        'books': results[6].docs.map((d) => d.data()).toList(),
        'book_transactions': results[7].docs.map((d) => d.data()).toList(),
        'notifications': results[8].docs.map((d) => d.data()).toList(),
        'seat_layouts': results[9].docs.map((d) => d.data()).toList(),
      },
    };

    final sanitized = _sanitizeForJson(backup);
    final json = const JsonEncoder.withIndent('  ').convert(sanitized);
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/library_backup_$timestamp.json');
    await file.writeAsString(json);
    return file.path;
    } catch (e) {
      throw Exception('Failed to export backup: $e');
    }
  }

  Future<void> shareBackup(String uid) async {
    final path = await exportBackup(uid);
    final file = XFile(path);
    await SharePlus.instance.share(
      ShareParams(files: [file], text: 'Library Manager Backup'),
    );
  }

  /// Import a JSON backup file and write all data to Firestore under [uid].
  Future<String?> importBackup(String uid, String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return 'File not found';

      final json = await file.readAsString();
      final data = jsonDecode(json) as Map<String, dynamic>;

      if (data['version'] == null) return 'Invalid backup file';
      if (data['data'] == null) return 'No data found in backup';

      final backupData = data['data'] as Map<String, dynamic>;
      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

      const collectionMap = {
        'students': 'students',
        'staff': 'staff',
        'seats': 'seats',
        'libraries': 'libraries',
        'attendance': 'attendance',
        'fees': 'fees',
        'books': 'books',
        'book_transactions': 'book_transactions',
        'notifications': 'notifications',
        'seat_layouts': 'seat_layouts',
      };

      for (final entry in collectionMap.entries) {
        final dataKey = entry.key;
        final collectionName = entry.value;
        final items = backupData[dataKey] as List<dynamic>?;
        if (items == null) continue;

        final col = userDoc.collection(collectionName);

        // Safely write imported docs in batches of 500 without preemptive deletion
        for (int i = 0; i < items.length; i += 500) {
          final batch = FirebaseFirestore.instance.batch();
          final chunk = items.skip(i).take(500);
          int itemIdx = 0;
          for (final item in chunk) {
            final map = Map<String, dynamic>.from(item as Map);
            final docId = pickBackupDocId(collectionName, map, i + itemIdx);
            final restored = _restoreFromJson(map) as Map<String, dynamic>;
            batch.set(col.doc(docId.toString()), restored, SetOptions(merge: true));
            itemIdx++;
          }
          await batch.commit();
        }
      }

      return null;
    } catch (e) {
      return 'Import failed. Please ensure the backup file is valid.';
    }
  }

  dynamic _sanitizeForJson(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(_sanitizeForJson(k), _sanitizeForJson(v)));
    }
    if (value is List) {
      return value.map(_sanitizeForJson).toList();
    }
    return value;
  }

  dynamic _restoreFromJson(dynamic value, {int depth = 0}) {
    if (depth > 100) return value;
    if (value is String && _isIsoDate(value)) {
      return Timestamp.fromDate(DateTime.parse(value));
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(
        _restoreFromJson(k, depth: depth + 1),
        _restoreFromJson(v, depth: depth + 1),
      ));
    }
    if (value is List) {
      return value.map((v) => _restoreFromJson(v, depth: depth + 1)).toList();
    }
    return value;
  }

  bool _isIsoDate(String s) {
    return s.length >= 20 && s[10] == 'T' && (s.endsWith('Z') || s.contains('+'));
  }

  /// Delete all data for the given [uid] from Firestore.
  Future<void> clearAllData(String uid) async {
    try {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
    final collections = [
      'students', 'staff', 'seats', 'libraries',
      'attendance', 'fees', 'notifications', 'books',
      'book_transactions', 'seat_layouts', 'settings',
    ];
    for (final name in collections) {
      final snapshot = await userDoc.collection(name).get();
      for (int i = 0; i < snapshot.docs.length; i += 500) {
        final chunk = snapshot.docs.skip(i).take(500);
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    } catch (e) {
      throw Exception('Failed to clear data: $e');
    }
  }
}
