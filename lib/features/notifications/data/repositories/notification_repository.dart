import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';
import '../../../../core/services/auto_backup_service.dart';
import '../../../../core/services/firestore_service.dart';

class NotificationRepository {
  final FirestoreService _fs;

  NotificationRepository(this._fs);

  Stream<List<NotificationModel>> getNotifications() {
    return _fs.notificationsCol
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList());
  }

  Stream<int> getUnreadCount() {
    return _fs.notificationsCol
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> addNotification(NotificationModel notification) async {
    final id = notification.notificationId.isEmpty
        ? const Uuid().v4()
        : notification.notificationId;
    final data = notification.toFirestore();
    data['notificationId'] = id;
    if (data['createdAt'] == null) {
      data['createdAt'] = DateTime.now();
    }
    await _fs.notificationsCol.doc(id).set(data);
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<void> markAsRead(String notificationId) async {
    await _fs.notificationsCol
        .doc(notificationId)
        .update({'isRead': true});
  }

  /// Deletes a single notification by its document id.
  Future<void> deleteNotification(String notificationId) async {
    await _fs.notificationsCol.doc(notificationId).delete();
  }

  /// Deletes multiple notifications (bulk). Chunked into 500-op batches to
  /// stay within Firestore's batch limits.
  Future<void> deleteNotifications(List<String> notificationIds) async {
    for (var i = 0; i < notificationIds.length; i += 500) {
      final chunk = notificationIds.skip(i).take(500);
      final batch = _fs.firestore.batch();
      for (final id in chunk) {
        batch.delete(_fs.notificationsCol.doc(id));
      }
      await batch.commit();
    }
  }

  Future<void> markAllAsRead() async {
    final snapshot = await _fs.notificationsCol
        .where('isRead', isEqualTo: false)
        .get();
    
    // Chunk into 500-op batches
    for (var i = 0; i < snapshot.docs.length; i += 500) {
      final chunk = snapshot.docs.skip(i).take(500);
      final batch = _fs.firestore.batch();
      for (final doc in chunk) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  /// Sends an instant update to students via the `sendStudentNotification`
  /// Cloud Function. The function writes the in-app notification under each
  /// student's subcollection AND pushes an FCM notification to the device
  /// bar for every registered device. Only students who joined the library
  /// (and registered a token) receive the push.
  Future<void> sendNotificationToStudent({
    required String title,
    required String body,
    String category = 'system',
    List<String>? targetStudentIds,
  }) async {
    // Record the update on the owner side too.
    final ownerNotif = NotificationModel(
      notificationId: const Uuid().v4(),
      title: title,
      body: body,
      category: category,
      data: targetStudentIds != null ? {'targetStudentIds': targetStudentIds} : null,
      createdAt: DateTime.now(),
    );
    await addNotification(ownerNotif);

    // Deliver to students (in-app + FCM push) via the server.
    try {
      final fn = FirebaseFunctions.instance;
      await fn.httpsCallable('sendStudentNotification').call<Map<String, dynamic>>({
        'studentIds': (targetStudentIds == null || targetStudentIds.isEmpty)
            ? 'all'
            : targetStudentIds,
        'title': title,
        'body': body,
        'category': category,
      });
    } catch (e) {
      // Surface the failure — do not silently swallow it.
      throw Exception('Failed to deliver to students: $e');
    }
  }
}
