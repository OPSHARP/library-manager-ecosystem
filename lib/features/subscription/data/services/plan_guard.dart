import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/firestore_service.dart';
import '../models/subscription_model.dart';

/// Thrown when a free-plan owner tries to exceed their feature limit.
class PlanLimitExceededException implements Exception {
  final String feature;
  final int limit;

  PlanLimitExceededException({required this.feature, required this.limit});

  @override
  String toString() =>
      'Free plan allows only $limit $feature. '
      '${AppConstants.upgradeToastMessage}';
}

/// Enforces free-plan feature limits.
///
/// Free-plan owners may only add 10 students, 10 seats, 10 attendance
/// records and 10 fee records. When a limit is reached, [guard] throws a
/// [PlanLimitExceededException] so the UI can show the upgrade prompt.
/// Pro subscribers (verified server-side and written by the Cloud Function)
/// are never blocked.
class PlanGuard {
  final FirestoreService _fs;

  PlanGuard(this._fs);

  DocumentReference<Map<String, dynamic>> get _subscriptionDoc =>
      _fs.firestore
          .collection('users')
          .doc(_fs.uid)
          .collection('subscription')
          .doc('current');

  /// Whether the owner currently has an active (unexpired) subscription.
  Future<bool> isPremium() async {
    try {
      final doc = await _subscriptionDoc.get();
      if (!doc.exists) return false;
      final sub = SubscriptionModel.fromMap(doc.data()!);
      if (!sub.isActive) return false;
      final expiresAt = sub.expiresAt;
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Throws [PlanLimitExceededException] if the owner is on the free plan and
  /// [currentCount] has already reached [limit].
  Future<void> guard({
    required String feature,
    required int limit,
    required int currentCount,
  }) async {
    if (currentCount < limit) return;
    if (await isPremium()) return;
    throw PlanLimitExceededException(feature: feature, limit: limit);
  }

  // ─── Feature-specific guards ───

  Future<void> guardStudentAdd() async {
    if (await isPremium()) return;
    final count = await _fs.studentsCol.count().get();
    await guard(
      feature: 'students',
      limit: AppConstants.maxStudents,
      currentCount: count.count ?? 0,
    );
  }

  Future<void> guardSeatAdd() async {
    if (await isPremium()) return;
    final count = await _fs.seatsCol.count().get();
    await guard(
      feature: 'seats',
      limit: AppConstants.maxSeats,
      currentCount: count.count ?? 0,
    );
  }

  Future<void> guardAttendanceAdd() async {
    if (await isPremium()) return;
    // Free plan allows at most maxAttendanceRecords (10).
    // Read only enough documents to reach the limit instead of scanning all historical dates.
    final snapshot = await _fs.attendanceCol.limit(AppConstants.maxAttendanceRecords).get();
    var total = 0;
    for (final doc in snapshot.docs) {
      final records = (doc.data()['records'] as List?) ?? const [];
      total += records.length;
      if (total >= AppConstants.maxAttendanceRecords) break;
    }
    await guard(
      feature: 'attendance records',
      limit: AppConstants.maxAttendanceRecords,
      currentCount: total,
    );
  }

  Future<void> guardFeeAdd() async {
    if (await isPremium()) return;
    final count = await _fs.feesCol.count().get();
    await guard(
      feature: 'fee records',
      limit: AppConstants.maxFees,
      currentCount: count.count ?? 0,
    );
  }
}
