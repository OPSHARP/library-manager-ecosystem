import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final fs = ref.watch(firestoreServiceProvider);
  return NotificationRepository(fs);
});

final notificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  return ref.watch(notificationRepositoryProvider).getNotifications();
});

final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  return ref.watch(notificationRepositoryProvider).getUnreadCount();
});
