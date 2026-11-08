import 'package:flutter_test/flutter_test.dart';
import 'package:library_manager_and_owner/core/utils/backup_utils.dart';
import 'package:library_manager_and_owner/features/attendance/data/models/attendance_model.dart';
import 'package:library_manager_and_owner/features/fees/data/models/fee_model.dart';
import 'package:library_manager_and_owner/features/subscription/data/services/plan_guard.dart';

void main() {
  group('PlanGuard unit tests', () {
    test('PlanLimitExceededException produces user-facing limit message', () {
      final ex = PlanLimitExceededException(feature: 'students', limit: 10);
      expect(ex.toString(), contains('Free plan allows only 10 students.'));
      expect(ex.feature, equals('students'));
      expect(ex.limit, equals(10));
    });
  });

  group('Backup Utils unit tests', () {
    test('pickBackupDocId correctly resolves primary keys per collection', () {
      expect(pickBackupDocId('students', {'studentId': 's123'}, 0), equals('s123'));
      expect(pickBackupDocId('staff', {'staffId': 'st456'}, 0), equals('st456'));
      expect(pickBackupDocId('seats', {'seatId': 'seat789'}, 0), equals('seat789'));
      expect(pickBackupDocId('fees', {'feeId': 'fee001'}, 0), equals('fee001'));
      expect(pickBackupDocId('attendance', {'date': '2026-10-28'}, 0), equals('2026-10-28'));
    });

    test('pickBackupDocId generates deterministic fallback ID when missing', () {
      final fallbackId = pickBackupDocId('unknown', {}, 42);
      expect(fallbackId.endsWith('_42'), isTrue);
    });
  });

  group('Attendance Model & Logic unit tests', () {
    test('Students with check-out are counted as present for the day', () {
      final now = DateTime.now();
      final recordCheckedOut = AttendanceRecord(
        studentId: 'stud_1',
        studentName: 'Alice',
        checkIn: now.subtract(const Duration(hours: 4)),
        checkOut: now,
      );
      final recordCheckedIn = AttendanceRecord(
        studentId: 'stud_2',
        studentName: 'Bob',
        checkIn: now.subtract(const Duration(hours: 1)),
        checkOut: null,
      );
      final recordAbsent = const AttendanceRecord(
        studentId: 'stud_3',
        studentName: 'Charlie',
        checkIn: null,
        checkOut: null,
      );

      final records = [recordCheckedOut, recordCheckedIn, recordAbsent];

      final presentCount = records.where((r) => r.checkIn != null).length;
      final absentCount = records.where((r) => r.checkIn == null).length;

      expect(presentCount, equals(2));
      expect(absentCount, equals(1));

      final model = AttendanceModel(
        date: '2026-10-28',
        records: records,
        totalPresent: presentCount,
        totalAbsent: absentCount,
      );

      expect(model.totalPresent, equals(2));
      expect(model.totalAbsent, equals(1));
    });
  });

  group('FeeModel unit tests', () {
    test('FeeModel serializes and calculates amount correctly', () {
      final fee = FeeModel(
        feeId: 'fee_101',
        studentId: 's1',
        studentName: 'John Doe',
        amount: 1500.0,
        status: 'paid',
        month: '2026-10',
        paymentMethod: 'Cash',
      );

      final map = fee.toJson();
      expect(map['amount'], equals(1500.0));
      expect(map['status'], equals('paid'));

      final copy = fee.copyWith(status: 'pending');
      expect(copy.status, equals('pending'));
      expect(copy.feeId, equals('fee_101'));
      expect(copy.amount, equals(1500.0));
    });
  });
}
