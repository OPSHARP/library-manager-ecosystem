import 'dart:math' show Random;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';
import '../../../../core/services/auto_backup_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../subscription/data/services/plan_guard.dart';

class StudentRepository {
  final FirestoreService _fs;
  StudentRepository(this._fs);

  Stream<List<StudentModel>> getStudents({String? search, String? filter}) {
    return _fs.studentsCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          var students = snap.docs
              .map((doc) => StudentModel.fromFirestore(doc))
              .toList();

          if (search != null && search.isNotEmpty) {
            final lower = search.toLowerCase();
            students = students
                .where(
                  (s) =>
                      s.name.toLowerCase().contains(lower) ||
                      (s.seatNumber?.toLowerCase().contains(lower) == true) ||
                      s.phone.toLowerCase().contains(lower),
                )
                .toList();
          }

          if (filter != null && filter != 'All') {
            switch (filter) {
              case 'Active':
                students = students.where((s) => s.isActive).toList();
                break;
              case 'Inactive':
                students = students.where((s) => !s.isActive).toList();
                break;
              case 'Fee Pending':
                students = students
                    .where((s) => s.feeStatus == 'pending')
                    .toList();
                break;
            }
          }

          return students;
        });
  }

  Future<StudentModel?> getStudent(String studentId) async {
    final doc = await _fs.studentsCol.doc(studentId).get();
    if (!doc.exists) return null;
    return StudentModel.fromFirestore(doc);
  }

  Future<String> addStudent(StudentModel student) async {
    await PlanGuard(_fs).guardStudentAdd();
    // The student's unique ID doubles as the Firestore document id so the
    // student portal can verify the student with a simple `get` (the rules
    // only allow single-doc `get` on the students subcollection, not list).
    final uniqueId = student.uniqueId.trim().isEmpty
        ? await _generateUniqueId()
        : student.uniqueId.trim().toUpperCase();
    final newStudent = student.copyWith(
      studentId: uniqueId,
      uniqueId: uniqueId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _fs.studentsCol.doc(uniqueId).set(newStudent.toFirestore());
    AutoBackupService.instance.triggerBackup(_fs.uid);
    return uniqueId;
  }

  static const _idAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Future<String> _generateUniqueId() async {
    final rand = Random();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = List.generate(
        6,
        (_) => _idAlphabet[rand.nextInt(_idAlphabet.length)],
      ).join();
      final doc = await _fs.studentsCol.doc(code).get();
      if (!doc.exists) return code;
    }
    // Last-resort: time-based suffix keeps it unique even if collisions persist.
    return '${_idAlphabet[rand.nextInt(_idAlphabet.length)]}'
        '${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase().substring(0, 5)}';
  }

  Future<void> updateStudent(StudentModel student) async {
    final newStudent = student.copyWith(updatedAt: DateTime.now());
    await _fs.studentsCol
        .doc(student.studentId)
        .set(newStudent.toFirestore(), SetOptions(merge: true));
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<void> deleteStudent(String studentId) async {
    await _fs.studentsCol.doc(studentId).delete();
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<void> deleteStudentAndReleaseSeat(
    String studentId,
    String? seatId,
  ) async {
    if (seatId != null && seatId.isNotEmpty) {
      await _fs.firestore.runTransaction((transaction) async {
        final seatRef = _fs.seatsCol.doc(seatId);
        final seatSnap = await transaction.get(seatRef);
        if (seatSnap.exists) {
          transaction.update(seatRef, {
            'status': 'available',
            'assignedStudentId': null,
            'assignedStudentName': null,
            'renewalDate': null,
          });
        }
        transaction.delete(_fs.studentsCol.doc(studentId));
      });
    } else {
      await _fs.studentsCol.doc(studentId).delete();
    }
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  /// Releases a student's seat WITHOUT deleting (or recreating) the student
  /// document — used by the ban flow so fees/attendance history is kept and
  /// the doc is not churn-deleted/recreated.
  Future<void> releaseSeat(String seatId) async {
    if (seatId.isEmpty) return;
    await _fs.firestore.runTransaction((transaction) async {
      final seatRef = _fs.seatsCol.doc(seatId);
      final seatSnap = await transaction.get(seatRef);
      if (seatSnap.exists) {
        transaction.update(seatRef, {
          'status': 'available',
          'assignedStudentId': null,
          'assignedStudentName': null,
          'renewalDate': null,
        });
      }
    });
    AutoBackupService.instance.triggerBackup(_fs.uid);
  }

  Future<int> getStudentCount() async {
    final snap = await _fs.studentsCol.count().get();
    return snap.count ?? 0;
  }

  Future<int> getActiveStudentCount() async {
    final snap = await _fs.studentsCol
        .where('isActive', isEqualTo: true)
        .count()
        .get();
    return snap.count ?? 0;
  }

  Future<List<StudentModel>> searchStudents(String query) async {
    final snap = await _fs.studentsCol
        .orderBy('createdAt', descending: true)
        .get();
    var students = snap.docs
        .map((doc) => StudentModel.fromFirestore(doc))
        .toList();
    if (query.isNotEmpty) {
      final lower = query.toLowerCase();
      students = students
          .where(
            (s) =>
                s.name.toLowerCase().contains(lower) ||
                (s.seatNumber?.toLowerCase().contains(lower) == true) ||
                s.phone.contains(query),
          )
          .toList();
    }
    return students;
  }
}
