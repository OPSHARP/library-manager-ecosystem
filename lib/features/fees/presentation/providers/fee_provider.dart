import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/fee_model.dart';
import '../../data/repositories/fee_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final feeRepositoryProvider = Provider<FeeRepository>((ref) {
  final fs = ref.watch(firestoreServiceProvider);
  return FeeRepository(fs);
});

final feeFilterProvider = StateProvider<String>((ref) => 'All');

/// Firestore stream — no sync-first needed.
final feesStreamProvider = StreamProvider<List<FeeModel>>((ref) {
  return ref.watch(feeRepositoryProvider).getFees();
});

/// Filtered fees — applies case-insensitive status filter client-side
final feesProvider = Provider<AsyncValue<List<FeeModel>>>((ref) {
  final feesAsync = ref.watch(feesStreamProvider);
  final filter = ref.watch(feeFilterProvider);

  return feesAsync.whenData((fees) {
    if (filter == 'All') return fees;
    return fees.where((f) => f.status.toLowerCase() == filter.toLowerCase()).toList();
  });
});

final monthlyCollectedProvider = Provider<double>((ref) {
  final fees = ref.watch(feesStreamProvider).valueOrNull ?? [];
  final now = DateTime.now();
  final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  return fees
      .where((f) => f.month == monthKey && f.status.toLowerCase() == 'paid')
      .fold(0.0, (sum, f) => sum + f.amount);
});

final monthlyPendingProvider = Provider<double>((ref) {
  final fees = ref.watch(feesStreamProvider).valueOrNull ?? [];
  final now = DateTime.now();
  final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  return fees
      .where((f) => f.month == monthKey && f.status.toLowerCase() != 'paid')
      .fold(0.0, (sum, f) => sum + f.amount);
});
