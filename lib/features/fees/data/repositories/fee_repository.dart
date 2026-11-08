import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/fee_model.dart';
import '../../../students/data/models/student_model.dart';
import '../../../../core/services/auto_backup_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../subscription/data/services/plan_guard.dart';

class FeeRepository {
  final FirestoreService _fs;
  FeeRepository(this._fs);

  // ─── Streams ───

  Stream<List<FeeModel>> getFees({String? filter}) {
    return _fs.feesCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      var fees =
          snap.docs.map((doc) => FeeModel.fromFirestore(doc)).toList();

      if (filter != null && filter != 'All') {
        fees = fees
            .where((f) => f.status.toLowerCase() == filter.toLowerCase())
            .toList();
      }

      return fees;
    });
  }

  Stream<List<FeeModel>> getStudentFees(String studentId) {
    return _fs.feesCol
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => FeeModel.fromFirestore(doc)).toList());
  }

  // ─── CRUD ───

  /// Resolves the real document reference for a fee. Normally the doc id
  /// equals the feeId field, but restored backups may have stored the doc
  /// under a different id (e.g. studentId). Falls back to a feeId-field query.
  Future<DocumentReference<Map<String, dynamic>>> _resolveFeeRef(
      String feeId) async {
    final direct = _fs.feesCol.doc(feeId);
    final directSnap = await direct.get();
    if (directSnap.exists) return direct;
    final byField = await _fs.feesCol
        .where('feeId', isEqualTo: feeId)
        .limit(1)
        .get();
    if (byField.docs.isNotEmpty) return byField.docs.first.reference;
    return direct;
  }

  Future<String> recordPayment(FeeModel fee) async {
    await PlanGuard(_fs).guardFeeAdd();
    final id = fee.feeId.isEmpty ? const Uuid().v4() : fee.feeId;
    final newFee = fee.copyWith().toFirestore();
    newFee['feeId'] = id;
    if (newFee['createdAt'] == null) {
      newFee['createdAt'] = FieldValue.serverTimestamp();
    }

    final batch = _fs.firestore.batch();
    batch.set(_fs.feesCol.doc(id), newFee);

    // Auto-sync the student's fee status, but ONLY if that student doc
    // already exists. A merge-set here otherwise becomes a CREATE, which
    // fails the rules' `createdAt is timestamp` check and denies the batch.
    final studentDoc = await _fs.studentsCol.doc(fee.studentId).get();
    if (studentDoc.exists) {
      batch.update(
        _fs.studentsCol.doc(fee.studentId),
        {
          'feeStatus': fee.status,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }

    await batch.commit();
    AutoBackupService.instance.triggerBackup(_fs.uid);
    return id;
  }

  Future<void> deleteFee(String feeId) async {
    final ref = await _resolveFeeRef(feeId);
    final doc = await ref.get();
    await ref.delete();

    // Resync the student's feeStatus from their remaining fees so the UI
    // reflects the deletion (avoids a stuck "paid" status).
    if (doc.exists) {
      try {
        final fee = FeeModel.fromFirestore(doc);
        final studentRef = _fs.studentsCol.doc(fee.studentId);
        final studentDoc = await studentRef.get();
        if (studentDoc.exists) {
          final remaining = await _fs.feesCol
              .where('studentId', isEqualTo: fee.studentId)
              .get();
          final allPaid = remaining.docs.isNotEmpty &&
              remaining.docs
                  .every((d) => FeeModel.fromFirestore(d).status == 'paid');
          await studentRef.update({
            'feeStatus': allPaid ? 'paid' : 'pending',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {
        // Non-critical: status resync failure should not block the delete.
      }
    }

    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<void> updateFeeStatus(String feeId, String status,
      {String? paymentMethod, String? transactionId}) async {
    final ref = await _resolveFeeRef(feeId);
    final doc = await ref.get();
    if (doc.exists) {
      final fee = FeeModel.fromFirestore(doc);
      final updated = fee.copyWith(
        status: status,
        paymentMethod: paymentMethod,
        transactionId: transactionId,
        paidDate: status == 'paid' ? DateTime.now() : fee.paidDate,
      );
      
      final batch = _fs.firestore.batch();
      batch.update(ref, updated.toFirestore());
      
      // Auto-sync the student's fee status, but only if that student doc
      // already exists (avoids CREATE-without-createdAt rule denial).
      final studentDoc = await _fs.studentsCol.doc(fee.studentId).get();
      if (studentDoc.exists) {
        batch.update(
          _fs.studentsCol.doc(fee.studentId),
          {
            'feeStatus': status,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
      
      await batch.commit();
      AutoBackupService.instance.triggerBackup(_fs.uid);
    }
  }

  Future<void> deleteFeesForStudent(String studentId) async {
    final snap = await _fs.feesCol
        .where('studentId', isEqualTo: studentId)
        .get();
    final batch = _fs.firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  // ─── Monthly aggregates ───

  Future<double> getMonthlyCollected() async {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final snap = await _fs.feesCol
        .where('month', isEqualTo: monthKey)
        .where('status', isEqualTo: 'paid')
        .get();

    double total = 0;
    for (final doc in snap.docs) {
      final fee = FeeModel.fromFirestore(doc);
      total += fee.amount;
    }
    return total;
  }

  Future<double> getMonthlyPending() async {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final snap = await _fs.feesCol
        .where('month', isEqualTo: monthKey)
        .get();

    double total = 0;
    for (final doc in snap.docs) {
      final fee = FeeModel.fromFirestore(doc);
      if (fee.status != 'paid') {
        total += fee.amount;
      }
    }
    return total;
  }

  Future<Map<String, double>> getRevenueBreakdown(int months) async {
    final breakdown = <String, double>{};
    final now = DateTime.now();

    for (int i = 0; i < months; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      breakdown[monthKey] = 0;
    }

    final firstDate = DateTime(now.year, now.month - months + 1, 1);
    final firstKey =
        '${firstDate.year}-${firstDate.month.toString().padLeft(2, '0')}';
    final lastKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final snap = await _fs.feesCol
        .where('month', isGreaterThanOrEqualTo: firstKey)
        .where('month', isLessThanOrEqualTo: lastKey)
        .where('status', isEqualTo: 'paid')
        .get();

    for (final doc in snap.docs) {
      final fee = FeeModel.fromFirestore(doc);
      if (breakdown.containsKey(fee.month)) {
        breakdown[fee.month] = breakdown[fee.month]! + fee.amount;
      }
    }

    return breakdown;
  }

  // ─── Auto-suspend overdue students ───

  Future<List<String>> autoSuspendOverdueStudents() async {
    final now = DateTime.now();
    final suspendedIds = <String>[];

    final results = await Future.wait([
      _fs.studentsCol.get(),
      _fs.feesCol.where('status', isNotEqualTo: 'paid').get(),
    ]);

    final studentsSnap = results[0];
    final feesSnap = results[1];

    final overdueFeesByStudent = <String, List<FeeModel>>{};
    for (final doc in feesSnap.docs) {
      final fee = FeeModel.fromFirestore(doc);
      if (fee.dueDate != null) {
        final daysOverdue = now.difference(fee.dueDate!).inDays;
        if (daysOverdue > 30) {
          overdueFeesByStudent
              .putIfAbsent(fee.studentId, () => [])
              .add(fee);
        }
      }
    }

    final batch = _fs.firestore.batch();
    for (final doc in studentsSnap.docs) {
      final student = StudentModel.fromFirestore(doc);

      if (student.status == 'suspended' ||
          student.status == 'graduated' ||
          student.status == 'alumni') {
        continue;
      }

      if (overdueFeesByStudent.containsKey(student.studentId)) {
        final updated = student.copyWith(status: 'suspended');
        batch.update(doc.reference, updated.toFirestore());
        suspendedIds.add(student.studentId);
      }
    }

    if (suspendedIds.isNotEmpty) {
      await batch.commit();
    }

    return suspendedIds;
  }
}
