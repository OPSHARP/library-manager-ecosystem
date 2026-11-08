import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final studentNoticesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final auth = ref.watch(authProvider);
  final ownerUid = auth.ownerUid;
  if (ownerUid == null || ownerUid.isEmpty) {
    return Stream.value([]);
  }
  final fs = FirestoreService(ownerUid);
  return fs.streamNotices();
});

