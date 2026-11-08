import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/attendance_model.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/offline_attendance_service.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final repo = AttendanceRepository(ref.watch(firestoreServiceProvider));
  OfflineAttendanceService.instance.registerRepository(repo);
  return repo;
});

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Caches attendance statistics for a specific student, preventing N+1 sequential reads.
final studentAttendanceStatsProvider = FutureProvider.family<Map<String, dynamic>, ({String studentId, DateTime? joiningDate})>((ref, params) async {
  if (params.joiningDate == null) return {};

  final repo = ref.watch(attendanceRepositoryProvider);

  int presentDays = 0;
  int totalDays = 0;
  int streak = 0;
  bool streakBroken = false;
  final last30 = <bool>[];

  final now = DateTime.now();
  final startDate = params.joiningDate!;
  final daysSinceJoining = now.difference(startDate).inDays + 1;

  // One range query (doc-id range on the YYYY-MM-DD keys) instead of N reads.
  final allDocs = await repo.getAttendanceRange(
    Formatters.firestoreDateKey(startDate),
    Formatters.firestoreDateKey(now),
  );

  // Map dateKey -> whether this student was present that day.
  final Map<String, bool> attendanceMap = {};
  for (final doc in allDocs) {
    attendanceMap[doc.date] = doc.records.any((r) => r.studentId == params.studentId && r.checkIn != null);
  }

  for (int i = 0; i < daysSinceJoining; i++) {
    final date = now.subtract(Duration(days: i));
    final dateKey = Formatters.firestoreDateKey(date);

    final present = attendanceMap[dateKey] ?? false;

    if (present) presentDays++;
    totalDays++;

    if (i < 30) last30.add(present);

    if (!streakBroken) {
      if (present) {
        streak++;
      } else if (i > 0) {
        streakBroken = true;
      }
    }
  }

  final percentage = totalDays > 0 ? (presentDays / totalDays * 100) : 0.0;

  return {
    'percentage': percentage,
    'streak': streak,
    'presentDays': presentDays,
    'totalDays': totalDays,
    'last30': last30,
  };
});

/// Real-time stream of attendance for the selected date from Firestore.
final attendanceProvider = StreamProvider<AttendanceModel>((ref) {
  final date = ref.watch(selectedDateProvider);
  return ref.watch(attendanceRepositoryProvider).getAttendance(date);
});
