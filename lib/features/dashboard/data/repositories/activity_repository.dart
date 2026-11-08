import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/auto_backup_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../models/activity_model.dart';

class ActivityRepository {
  final FirestoreService _fs;

  ActivityRepository(this._fs);

  CollectionReference<Map<String, dynamic>> get _col => _fs.activitiesCol;

  /// Log a new activity entry
  Future<void> logActivity({
    required String type,
    required String description,
    String? relatedId,
  }) async {
    await _col.add({
      'type': type,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'relatedId': relatedId,
    });
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  /// Stream the most recent activities
  Stream<List<ActivityModel>> streamRecentActivities({int limit = 10}) {
    return _col
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityModel.fromFirestore(doc))
            .toList());
  }
}
