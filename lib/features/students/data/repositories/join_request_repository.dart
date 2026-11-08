import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class JoinRequestRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<Map<String, dynamic>>> getJoinRequests() {
    if (_uid == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('join_requests')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  Future<void> acceptRequest(String studentUid) async {
    final fn = _functions.httpsCallable('acceptJoinRequest');
    await fn.call({'studentUid': studentUid});
    // Auto-delete the "New Join Request" notification(s) for this student so
    // approving the request clears the bell instead of leaving stale unread
    // notifications behind.
    await _deleteStudentNotifications(studentUid);
  }

  Future<void> declineRequest(String studentUid) async {
    if (_uid == null) return;
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('join_requests')
        .doc(studentUid)
        .delete();
    // Auto-delete the "New Join Request" notification(s) for this student so
    // rejecting the request clears the bell instead of leaving stale unread
    // notifications behind.
    await _deleteStudentNotifications(studentUid);
  }

  /// Deletes the owner's "New Join Request" / "Leave Request" notifications
  /// tied to a given student uid. Notifications carry the student's uid in
  /// `data.studentUid`, so we can target exactly the right docs.
  Future<void> _deleteStudentNotifications(String studentUid) async {
    if (_uid == null || studentUid.isEmpty) return;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('notifications')
          .where('data.studentUid', isEqualTo: studentUid)
          .get();
      if (snap.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {
      // Notification cleanup is best-effort — approving/rejecting the request
      // must not fail because a notification could not be deleted.
    }
  }
}
