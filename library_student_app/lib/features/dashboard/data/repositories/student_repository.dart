import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/firestore_service.dart';
import '../models/student_model.dart';
import '../models/seat_model.dart';
import '../models/book_model.dart';
import '../models/fee_model.dart';
import '../models/attendance_model.dart';
import '../models/library_model.dart';

class StudentRepository {
  final FirestoreService _firestore;

  StudentRepository(this._firestore);

  Future<StudentModel?> getStudent(String studentId) async {
    try {
      final data = await _firestore.getStudentById(studentId);
      if (data == null) return null;
      return StudentModel.fromJson(data);
    } on FirebaseException catch (e) {
      // Before the owner registers/binds this student, the rules deny the
      // read (or the doc does not exist). Treat that as "not registered" so
      // the dashboard stays in public mode (Link Student ID card) instead of
      // surfacing a permission error.
      if (e.code == 'permission-denied' || e.code == 'not-found') {
        return null;
      }
      rethrow;
    }
  }

  Stream<StudentModel?> streamStudent(String studentId) {
    return _firestore
        .streamDocument('students', studentId)
        .map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return StudentModel.fromJson(data);
    });
  }

  Future<SeatModel?> getSeat(String seatId) async {
    final data = await _firestore.getSeatById(seatId);
    if (data == null) return null;
    return SeatModel.fromJson(data);
  }

  Stream<List<SeatModel>> streamAllSeats() {
    return _firestore.streamAllSeats().map((snapshot) {
      return snapshot.docs
          .map((doc) => SeatModel.fromJson(doc.data()))
          .toList();
    });
  }

  Future<LibraryModel?> getLibrary(String ownerId) async {
    final data = await _firestore.getLibraryByOwnerId(ownerId);
    if (data == null) return null;
    return LibraryModel.fromJson(data);
  }

  Stream<LibraryModel?> streamLibrary(String ownerId) {
    return _firestore.streamLibraryByOwner(ownerId).map((data) {
      if (data == null) return null;
      return LibraryModel.fromJson(data);
    });
  }

  Future<List<BookModel>> getStudentBooks(String studentId) async {
    final data = await _firestore.getStudentBooks(studentId);
    return data.map((d) => BookModel.fromJson(d)).toList();
  }

  /// Full library book catalog (all copies/docs, issued or not).
  Future<List<BookModel>> getAllBooks() async {
    final data = await _firestore.getAllBooks();
    return data.map((d) => BookModel.fromJson(d)).toList();
  }

  Future<List<FeeModel>> getStudentFees(String studentId) async {
    final data = await _firestore.getStudentFees(studentId);
    return data.map((d) => FeeModel.fromJson(d)).toList();
  }

  Future<List<AttendanceModel>> getAllAttendance({String? studentId}) async {
    final data = await _firestore.getStudentAttendanceList();
    return data.map((d) => AttendanceModel.fromJson(d, forStudentId: studentId)).toList();
  }

  int countAttendanceForStudent(List<AttendanceModel> attendance, String studentId) {
    int present = 0;
    for (final day in attendance) {
      for (final record in day.records) {
        if (record.studentId == studentId) {
          present++;
        }
      }
    }
    return present;
  }

  int countMissedForStudent(int totalDays, int presentDays) {
    return totalDays - presentDays;
  }
}
