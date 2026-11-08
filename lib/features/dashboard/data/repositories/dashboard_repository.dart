import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dashboard_stats_model.dart';
import '../../../library_setup/data/repositories/library_repository.dart';
import '../../../seats/data/models/seat_model.dart';
import '../../../attendance/data/models/attendance_model.dart';
import '../../../students/data/models/student_model.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/firestore_service.dart';

class DashboardRepository {
  final FirestoreService _fs;
  final LibraryRepository _libraryRepository;

  DashboardRepository(this._fs, this._libraryRepository);

  /// Single fetch of all dashboard stats from Firestore.
  Future<DashboardStatsModel> getDashboardStats() async {
    final libraryId = await _libraryRepository.getCurrentLibraryId();
    if (libraryId == null) return const DashboardStatsModel();

    final library = await _libraryRepository.getLibrarySync(libraryId);
    if (library == null) return const DashboardStatsModel();

    final results = await Future.wait([
      _getStudentStats(),
      _getSeatStats(),
      _getTodayAttendance(),
      _getFeeStats(),
      _getWeeklyAttendance(),
      _getMonthlyRevenueHistory(),
      _getMonthlyExpenses(),
    ]);

    final studentStats = results[0] as Map<String, int>;
    final seatStats = results[1] as Map<String, int>;
    final attendance = results[2] as Map<String, int>;
    final fees = results[3] as Map<String, double>;
    final weeklyAtt = results[4] as List<double>;
    final monthlyRev = results[5] as List<double>;
    final monthlyExp = results[6] as double;

    return DashboardStatsModel.fromData(
      totalStudents: studentStats['total'] ?? 0,
      activeStudents: studentStats['active'] ?? 0,
      totalSeats: seatStats['total'] ?? 0,
      occupiedSeats: seatStats['occupied'] ?? 0,
      availableSeats: seatStats['available'] ?? 0,
      reservedSeats: seatStats['reserved'] ?? 0,
      todayPresent: attendance['present'] ?? 0,
      todayAbsent: attendance['absent'] ?? 0,
      monthlyRevenue: fees['revenue'] ?? 0,
      monthlyExpenses: monthlyExp,
      pendingFees: fees['pending'] ?? 0,
      collectedFees: fees['collected'] ?? 0,
      weeklyAttendance: weeklyAtt,
      monthlyRevenueHistory: monthlyRev,
    );
  }

  /// Stream that re-emits whenever seats, attendance, or fees change.
  /// Listens to all collection snapshots and recomputes on any change.
  Stream<DashboardStatsModel> watchDashboardStats() {
    final controller = StreamController<DashboardStatsModel>.broadcast();
    DashboardStatsModel? last;

    Future<void> refresh() async {
      try {
        final stats = await getDashboardStats();
        if (last != stats) {
          last = stats;
          controller.add(stats);
        }
      } catch (e) {
        controller.addError(e);
      }
    }

    final dateKey = Formatters.firestoreDateKey(DateTime.now());

    final sub1 = _fs.seatsCol.snapshots().listen((_) {
      refresh();
    });

    final sub2 = _fs.attendanceCol.doc(dateKey).snapshots().listen((_) {
      refresh();
    });

    final sub3 = _fs.feesCol.snapshots().listen((_) {
      refresh();
    });

    final sub4 = _fs.librariesCol.snapshots().listen((_) {
      refresh();
    });

    final sub5 = _fs.studentsCol.snapshots().listen((_) {
      refresh();
    });

    final sub6 = _fs.expensesCol.snapshots().listen((_) {
      refresh();
    });

    // Initial load
    refresh();

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
      sub3.cancel();
      sub4.cancel();
      sub5.cancel();
      sub6.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // ─── Private helpers ───

  Future<Map<String, int>> _getStudentStats() async {
    final snapshot = await _fs.studentsCol.get();
    int total = snapshot.docs.length;
    int active = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['isActive'] == true) active++;
    }
    return {'total': total, 'active': active};
  }

  Future<Map<String, int>> _getSeatStats() async {
    final snapshot = await _fs.seatsCol.get();
    int total = 0;
    int occupied = 0;
    int available = 0;
    int reserved = 0;
    for (final doc in snapshot.docs) {
      total++;
      final seat = SeatModel.fromFirestore(doc);
      switch (seat.status) {
        case 'occupied':
          occupied++;
          break;
        case 'available':
          available++;
          break;
        case 'reserved':
          reserved++;
          break;
      }
    }
    return {
      'total': total,
      'occupied': occupied,
      'available': available,
      'reserved': reserved,
    };
  }

  Future<Map<String, int>> _getTodayAttendance() async {
    final dateKey = Formatters.firestoreDateKey(DateTime.now());
    int present = 0;
    int absent = 0;
    try {
      final doc = await _fs.attendanceCol.doc(dateKey).get();
      if (doc.exists) {
        final att = AttendanceModel.fromFirestore(doc);
        present = att.totalPresent;
        absent = att.totalAbsent;
      }
    } catch (_) {
    }
    return {'present': present, 'absent': absent};
  }

  Future<Map<String, double>> _getFeeStats() async {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final snapshot = await _fs.feesCol
        .where('month', isEqualTo: monthKey)
        .get();

    double monthlyRevenue = 0;
    double pendingFees = 0;
    double collectedFees = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num? ?? 0).toDouble();
      if (data['status'] == 'paid') {
        collectedFees += amount;
        monthlyRevenue += amount;
      } else {
        pendingFees += amount;
      }
    }

    return {
      'revenue': monthlyRevenue,
      'pending': pendingFees,
      'collected': collectedFees,
    };
  }

  /// Returns present count for each of the last 7 days (Mon..Sun order).
  Future<List<double>> _getWeeklyAttendance() async {
    final now = DateTime.now();
    // Go back to the most recent Monday
    final today = DateTime(now.year, now.month, now.day);
    final daysFromMonday = (today.weekday - 1) % 7;
    final monday = today.subtract(Duration(days: daysFromMonday));

    final List<double> weekly = [];
    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      if (date.isAfter(today)) {
        weekly.add(0);
        continue;
      }
      final dateKey = Formatters.firestoreDateKey(date);
      try {
        final doc = await _fs.attendanceCol.doc(dateKey).get();
        if (doc.exists) {
          final att = AttendanceModel.fromFirestore(doc);
          weekly.add(att.totalPresent.toDouble());
        } else {
          weekly.add(0);
        }
      } catch (_) {
        weekly.add(0);
      }
    }
    return weekly;
  }

  /// Returns total collected revenue for each of the last 6 months.
  Future<List<double>> _getMonthlyRevenueHistory() async {
    final now = DateTime.now();
    final List<double> history = [];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      double total = 0;
      try {
        final snapshot =
            await _fs.feesCol.where('month', isEqualTo: monthKey).get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (data['status'] == 'paid') {
            total += (data['amount'] as num? ?? 0).toDouble();
          }
        }
      } catch (_) {
        history.add(0);
        continue;
      }
      history.add(total);
    }
    return history;
  }

  Future<List<MapEntry<String, double>>> calculateTopStudents(
    List<StudentModel> students,
  ) async {
    final now = DateTime.now();
    final Map<String, int> presentCounts = {};
    int totalDays = 0;

    for (var i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = Formatters.firestoreDateKey(date);
      final doc = await _fs.attendanceCol.doc(dateKey).get();
      if (doc.exists) {
        final att = AttendanceModel.fromFirestore(doc);
        totalDays++;
        for (final record in att.records) {
          if (record.checkIn != null) {
            presentCounts[record.studentId] =
                (presentCounts[record.studentId] ?? 0) + 1;
          }
        }
      }
    }

    if (totalDays == 0) return [];

    final entries = <MapEntry<String, double>>[];
    for (final student in students) {
      final count = presentCounts[student.studentId] ?? 0;
      final percentage = (count / totalDays) * 100;
      entries.add(MapEntry(student.name, percentage));
    }

    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  Future<double> _getMonthlyExpenses() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final nextMonth = now.month == 12
          ? DateTime(now.year + 1, 1, 1)
          : DateTime(now.year, now.month + 1, 1);
      final endOfMonth = nextMonth.subtract(const Duration(milliseconds: 1));

      final snap = await _fs.expensesCol
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      var total = 0.0;
      for (final doc in snap.docs) {
        final d = doc.data();
        total += (d['amount'] ?? 0).toDouble();
      }
      return total;
    } catch (_) {
      return 0.0;
    }
  }
}
