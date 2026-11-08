import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/seat_model.dart';
import '../../data/models/seat_layout_model.dart';
import '../../data/repositories/seat_repository.dart';
import '../../data/repositories/seat_layout_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final seatRepositoryProvider = Provider<SeatRepository>((ref) {
  return SeatRepository(ref.watch(firestoreServiceProvider));
});

final seatLayoutRepositoryProvider = Provider<SeatLayoutRepository>((ref) {
  return SeatLayoutRepository(ref.watch(firestoreServiceProvider));
});

final seatCategoryProvider = StateProvider<String>((ref) => 'All');

/// Real-time stream of seats from Firestore.
final seatsStreamProvider = StreamProvider<List<SeatModel>>((ref) {
  return ref.watch(seatRepositoryProvider).getSeats();
});

/// Filtered seats - applies category filter client-side.
final seatsProvider = Provider<AsyncValue<List<SeatModel>>>((ref) {
  final seatsAsync = ref.watch(seatsStreamProvider);
  final category = ref.watch(seatCategoryProvider);

  return seatsAsync.whenData((seats) {
    if (category == 'All') return seats;
    if (category == 'Reserved') {
      return seats.where((s) => s.status == 'reserved').toList();
    }
    return seats.where((s) => s.category == category).toList();
  });
});

/// Real-time stream of the seat layout from Firestore.
final seatLayoutProvider = StreamProvider<SeatLayoutModel?>((ref) {
  return ref.watch(seatLayoutRepositoryProvider).getLayout();
});
