import 'package:uuid/uuid.dart';
import '../models/notice_model.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/auto_backup_service.dart';

class NoticeRepository {
  final FirestoreService _fs;

  NoticeRepository(this._fs);

  Stream<List<NoticeModel>> getNotices() {
    return _fs.noticesCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => NoticeModel.fromFirestore(d)).toList())
        .handleError((_) => <NoticeModel>[]);
  }

  Future<void> addNotice({
    required String title,
    required String message,
    String priority = 'normal',
  }) async {
    final id = const Uuid().v4();
    final notice = NoticeModel(
      noticeId: id,
      title: title,
      message: message,
      priority: priority,
      isActive: true,
      createdAt: DateTime.now(),
    );
    await _fs.noticesCol.doc(id).set(notice.toFirestore());
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<void> deleteNotice(String noticeId) async {
    await _fs.noticesCol.doc(noticeId).delete();
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }
}

