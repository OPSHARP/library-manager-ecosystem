import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/staff_model.dart';
import '../../data/repositories/staff_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  final fs = ref.watch(firestoreServiceProvider);
  return StaffRepository(fs);
});

/// Firestore stream — no sync-first needed.
final staffProvider = StreamProvider<List<StaffModel>>((ref) {
  return ref.watch(staffRepositoryProvider).getStaff();
});
