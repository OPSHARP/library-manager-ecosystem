import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/student_model.dart';
import '../../data/repositories/student_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  final fs = ref.watch(firestoreServiceProvider);
  return StudentRepository(fs);
});

final studentsSearchProvider = StateProvider<String>((ref) => '');
final studentsFilterProvider = StateProvider<String>((ref) => 'All');

/// Pure Firestore stream — no sync-first needed since Firestore snapshots
/// deliver data fast and the stream itself is the source of truth.
final studentsStreamProvider = StreamProvider<List<StudentModel>>((ref) {
  final repo = ref.watch(studentRepositoryProvider);
  return repo.getStudents();
});

/// Filtered students — applies search/filter client-side on top of the stream
final studentsProvider = Provider<AsyncValue<List<StudentModel>>>((ref) {
  final studentsAsync = ref.watch(studentsStreamProvider);
  final search = ref.watch(studentsSearchProvider);
  final filter = ref.watch(studentsFilterProvider);

  return studentsAsync.whenData((students) {
    var result = students;
    if (search.isNotEmpty) {
      final lower = search.toLowerCase();
      result = result
          .where((s) =>
              s.name.toLowerCase().contains(lower) ||
              (s.seatNumber?.toLowerCase().contains(lower) == true) ||
              s.phone.contains(search))
          .toList();
    }
    if (filter != 'All') {
      switch (filter) {
        case 'Active':
          result = result.where((s) => s.isActive).toList();
          break;
        case 'Inactive':
          result = result.where((s) => !s.isActive).toList();
          break;
        case 'Fee Pending':
          result = result.where((s) => s.feeStatus != 'paid').toList();
          break;
      }
    }
    return result;
  });
});

final studentCountProvider = Provider<int>((ref) {
  return ref.watch(studentsStreamProvider).valueOrNull?.length ?? 0;
});
