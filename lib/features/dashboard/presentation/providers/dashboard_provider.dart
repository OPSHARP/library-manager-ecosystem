import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/dashboard_stats_model.dart';
import '../../data/models/activity_model.dart';
import '../../../library_setup/data/models/library_model.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/activity_repository.dart';
import '../../../library_setup/data/repositories/library_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../students/presentation/providers/student_provider.dart';
import '../../../students/data/models/student_model.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  final fs = ref.watch(firestoreServiceProvider);
  return LibraryRepository(fs);
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final fs = ref.watch(firestoreServiceProvider);
  return DashboardRepository(fs, ref.watch(libraryRepositoryProvider));
});

/// Keeps the libraryIdProvider for backward compatibility with screens
/// that still read the libraryId. In Firestore mode the library doc is
/// always 'current', so this simply returns the uid-based libraryId.
final libraryIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null ? 'lib_${user.uid}' : null;
});

/// Real-time stream of the current user's LibraryModel.
final libraryModelProvider = StreamProvider<LibraryModel?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(libraryRepositoryProvider).getLibrary('lib_${user.uid}');
});

final dashboardStatsProvider = StreamProvider<DashboardStatsModel>((ref) {
  return ref.watch(dashboardRepositoryProvider).watchDashboardStats();
});

final topStudentsProvider = FutureProvider<List<MapEntry<String, double>>>((ref) async {
  final studentsAsync = ref.watch(studentsStreamProvider);
  final students = studentsAsync.valueOrNull;
  if (students == null || students.isEmpty) return [];
  return ref.watch(dashboardRepositoryProvider).calculateTopStudents(students);
});

/// Repository for logging and fetching activities
final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final fs = ref.watch(firestoreServiceProvider);
  return ActivityRepository(fs);
});

/// Stream of recent activities for the dashboard
final recentActivitiesProvider = StreamProvider<List<ActivityModel>>((ref) {
  final repo = ref.watch(activityRepositoryProvider);
  return repo.streamRecentActivities(limit: 10);
});

/// Students whose membership/fee is expiring within 7 days
final expiringMembershipsProvider = Provider<List<_ExpiringStudent>>((ref) {
  final studentsAsync = ref.watch(studentsStreamProvider);
  final students = studentsAsync.valueOrNull;
  if (students == null || students.isEmpty) return [];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final cutoff = today.add(const Duration(days: 7));

  final expiring = <_ExpiringStudent>[];
  for (final s in students) {
    if (!s.isActive) continue;
    if (s.nextDueDate == null) continue;
    final dueDay = DateTime(s.nextDueDate!.year, s.nextDueDate!.month, s.nextDueDate!.day);
    if (!dueDay.isBefore(today) && dueDay.isBefore(cutoff)) {
      final daysRemaining = dueDay.difference(today).inDays;
      expiring.add(_ExpiringStudent(
        student: s,
        daysRemaining: daysRemaining,
      ));
    }
  }

  expiring.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
  return expiring;
});

class _ExpiringStudent {
  final StudentModel student;
  final int daysRemaining;
  const _ExpiringStudent({required this.student, required this.daysRemaining});
}
