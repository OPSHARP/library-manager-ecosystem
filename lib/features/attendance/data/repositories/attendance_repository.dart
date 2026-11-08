import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/auto_backup_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/offline_attendance_service.dart';
import '../../../subscription/data/services/plan_guard.dart';

class AttendanceRepository {
  final FirestoreService _fs;

  AttendanceRepository(this._fs);

  // ─── Streams ───

  /// Real-time stream of attendance for a specific date.
  Stream<AttendanceModel> getAttendance(DateTime date) {
    final dateKey = Formatters.firestoreDateKey(date);
    return _fs.attendanceCol.doc(dateKey).snapshots().map((doc) {
      if (!doc.exists) return AttendanceModel.empty(dateKey);
      return AttendanceModel.fromFirestore(doc);
    });
  }

  // ─── Mark attendance (transaction for read-modify-write safety) ───

  /// Direct Firestore commit for an attendance record (used by online calls and queue syncing).
  Future<void> markAttendanceDirect({
    required String dateKey,
    required AttendanceRecord record,
  }) async {
    final docRef = _fs.attendanceCol.doc(dateKey);

    // Enforce the free-plan limit only when adding a brand-new record.
    // Updating an existing record (e.g. check-out toggle) is never blocked.
    final existingDoc = await docRef.get();
    var isNewRecord = true;
    if (existingDoc.exists) {
      final existing = AttendanceModel.fromFirestore(existingDoc);
      isNewRecord =
          existing.records.indexWhere((r) => r.studentId == record.studentId) <
              0;
    }
    if (isNewRecord) {
      await PlanGuard(_fs).guardAttendanceAdd();
    }

    await _fs.firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (snapshot.exists) {
        final existing = AttendanceModel.fromFirestore(snapshot);
        final records = List<AttendanceRecord>.from(existing.records);

        final idx = records.indexWhere((r) => r.studentId == record.studentId);
        if (idx >= 0) {
          records[idx] = record;
        } else {
          records.add(record);
        }

        final present = records.where((r) => r.checkIn != null).length;
        final absent = records.where((r) => r.checkIn == null).length;

        final updated = AttendanceModel(
          date: dateKey,
          records: records,
          totalPresent: present,
          totalAbsent: absent,
        );

        transaction.set(docRef, updated.toFirestore(), SetOptions(merge: true));
      } else {
        final isPresent = record.checkIn != null;
        final updated = AttendanceModel(
          date: dateKey,
          records: [record],
          totalPresent: isPresent ? 1 : 0,
          totalAbsent: isPresent ? 0 : 1,
        );
        transaction.set(docRef, updated.toFirestore(), SetOptions(merge: true));
      }
    });
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  /// High-level attendance marking with offline resiliency.
  /// If device is offline or network fails, automatically enqueues locally for auto-sync.
  Future<void> markAttendance({
    required String dateKey,
    required AttendanceRecord record,
  }) async {
    final online = await OfflineAttendanceService.instance.isOnline();
    if (!online) {
      await OfflineAttendanceService.instance.enqueue(
        dateKey: dateKey,
        record: record,
      );
      return;
    }

    try {
      await markAttendanceDirect(dateKey: dateKey, record: record);
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        await OfflineAttendanceService.instance.enqueue(
          dateKey: dateKey,
          record: record,
        );
        return;
      }
      rethrow;
    } catch (e) {
      if (e is! PlanLimitExceededException &&
          (e.toString().contains('network') ||
           e.toString().contains('unavailable') ||
           e.toString().contains('SocketException'))) {
        await OfflineAttendanceService.instance.enqueue(
          dateKey: dateKey,
          record: record,
        );
        return;
      }
      rethrow;
    }
  }

  // ─── Check out (transaction) ───

  /// Direct Firestore commit for student check-out (used by online calls and queue syncing).
  Future<void> checkOutDirect({
    required String dateKey,
    required String studentId,
    DateTime? checkOutTime,
  }) async {
    final docRef = _fs.attendanceCol.doc(dateKey);
    final time = checkOutTime ?? DateTime.now();

    await _fs.firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final existing = AttendanceModel.fromFirestore(snapshot);
      final records = List<AttendanceRecord>.from(existing.records);

      final idx = records.indexWhere((r) => r.studentId == studentId);
      if (idx < 0) return;

      records[idx] = AttendanceRecord(
        studentId: records[idx].studentId,
        studentName: records[idx].studentName,
        checkIn: records[idx].checkIn,
        checkOut: time,
        method: records[idx].method,
        isLate: records[idx].isLate,
      );

      final present = records.where((r) => r.checkIn != null).length;
      final absent = records.where((r) => r.checkIn == null).length;

      final updated = AttendanceModel(
        date: dateKey,
        records: records,
        totalPresent: present,
        totalAbsent: absent,
      );

      transaction.set(docRef, updated.toFirestore(), SetOptions(merge: true));
    });
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  /// High-level check-out with offline resiliency.
  Future<void> checkOut({
    required String dateKey,
    required String studentId,
    DateTime? checkOutTime,
  }) async {
    final online = await OfflineAttendanceService.instance.isOnline();
    if (!online) {
      await OfflineAttendanceService.instance.enqueueCheckOut(
        dateKey: dateKey,
        studentId: studentId,
        checkOutTime: checkOutTime,
      );
      return;
    }

    try {
      await checkOutDirect(
        dateKey: dateKey,
        studentId: studentId,
        checkOutTime: checkOutTime,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        await OfflineAttendanceService.instance.enqueueCheckOut(
          dateKey: dateKey,
          studentId: studentId,
          checkOutTime: checkOutTime,
        );
        return;
      }
      rethrow;
    } catch (e) {
      if (e.toString().contains('network') ||
          e.toString().contains('unavailable') ||
          e.toString().contains('SocketException')) {
        await OfflineAttendanceService.instance.enqueueCheckOut(
          dateKey: dateKey,
          studentId: studentId,
          checkOutTime: checkOutTime,
        );
        return;
      }
      rethrow;
    }
  }

  // ─── Queries ───

  /// Raw document snapshot for a date key — useful for one-off existence checks.
  Future<DocumentSnapshot<Map<String, dynamic>>> getAttendanceDoc(String dateKey) {
    return _fs.attendanceCol.doc(dateKey).get();
  }

  Future<int> getTodayPresent() async {
    final dateKey = Formatters.firestoreDateKey(DateTime.now());
    final doc = await _fs.attendanceCol.doc(dateKey).get();
    if (!doc.exists) return 0;
    final data = doc.data();
    return data?['totalPresent'] ?? 0;
  }

  /// Remove all attendance records for a student across all dates.
  /// Queries all docs, filters out the student, batch-updates changed docs.
  /// Chunks into batches of 400 to stay under Firestore's 500-op limit.
  Future<void> removeStudentRecords(String studentId) async {
    final snapshot = await _fs.attendanceCol.get();
    var batch = _fs.firestore.batch();
    int opCount = 0;

    for (final doc in snapshot.docs) {
      final attendance = AttendanceModel.fromFirestore(doc);
      final filtered = attendance.records.where((r) => r.studentId != studentId).toList();

      if (filtered.length < attendance.records.length) {
        final present = filtered.where((r) => r.checkIn != null).length;
        final absent = filtered.where((r) => r.checkIn == null).length;

        final updated = AttendanceModel(
          date: attendance.date,
          records: filtered,
          totalPresent: present,
          totalAbsent: absent,
        );

        batch.set(doc.reference, updated.toFirestore(), SetOptions(merge: true));
        opCount++;

        if (opCount >= 400) {
          await batch.commit();
          batch = _fs.firestore.batch();
          opCount = 0;
        }
      }
    }

    if (opCount > 0) {
      await batch.commit();
    }
  }

  /// Monthly attendance report: reads docs for [month] in a single range query.
  Future<Map<String, dynamic>> getMonthlyAttendanceReport(DateTime month) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);
    final startKey = Formatters.firestoreDateKey(startDate);
    final endKey = Formatters.firestoreDateKey(endDate);

    final docs = await getAttendanceRange(startKey, endKey);
    final totalDays = docs.length;
    final totalPresent = docs.fold<int>(0, (acc, doc) => acc + doc.totalPresent);

    return {
      'totalDays': totalDays,
      'totalPresent': totalPresent,
      'averageAttendance': totalDays > 0 ? totalPresent / totalDays : 0,
    };
  }

  /// Fetches all attendance documents in an inclusive date range using a
  /// document-ID range query (the attendance doc id is the `YYYY-MM-DD` key).
  /// This is a single query — far cheaper than N sequential per-day reads.
  Future<List<AttendanceModel>> getAttendanceRange(
    String startKey,
    String endKey,
  ) async {
    final snapshot = await _fs.attendanceCol
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startKey)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endKey)
        .get();
    return snapshot.docs
        .map((doc) => AttendanceModel.fromFirestore(doc))
        .toList();
  }
}
