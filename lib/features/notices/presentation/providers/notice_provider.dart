import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notice_model.dart';
import '../../data/repositories/notice_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final noticeRepositoryProvider = Provider<NoticeRepository>((ref) {
  final fs = ref.watch(firestoreServiceProvider);
  return NoticeRepository(fs);
});

final noticesStreamProvider = StreamProvider<List<NoticeModel>>((ref) {
  final repo = ref.watch(noticeRepositoryProvider);
  return repo.getNotices();
});
