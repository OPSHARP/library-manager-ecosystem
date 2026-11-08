import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/join_request_repository.dart';

final joinRequestRepositoryProvider = Provider<JoinRequestRepository>((ref) {
  return JoinRequestRepository();
});

final joinRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(joinRequestRepositoryProvider);
  return repo.getJoinRequests();
});
