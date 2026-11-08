import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';

/// Central FCM + local-notification service for the student portal.
///
/// Responsibilities:
///  * Request permission and obtain the device's FCM token.
///  * Persist the token on the joined library's student document so the
///    owner's Cloud Function can push device-bar notifications to it.
///    (A token is only written after the student has joined that library, so
///    non-joined students never receive pushes.)
///  * Show device-bar notifications while the app is in the foreground
///    (FCM background/terminated messages show automatically).
///  * Navigate to the in-app notifications screen when a push is tapped.
class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  static String? _currentFcmToken;
  static bool _handlersInstalled = false;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const _channelId = 'library_updates';
  static const _channelName = 'Library Updates';

  String? get currentToken => _currentFcmToken;

  /// Must be called once from main().
  Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    // We no longer request permission here to avoid prompting on app start.
    // Permission is requested later when the user actually reaches the dashboard.
    
    _currentFcmToken = await messaging.getToken();

    // Keep token fresh (e.g. app reinstall / Play Services update).
    messaging.onTokenRefresh.listen((token) {
      _currentFcmToken = token;
    });

    // Local notifications used to show device-bar notifications while the
    // app is in the foreground.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (_) => _navigateToNotifications(),
    );

    if (!_handlersInstalled) {
      _handlersInstalled = true;

      // Foreground push → show a device-bar notification via the local plugin.
      FirebaseMessaging.onMessage.listen((message) {
        final title = message.notification?.title ?? 'Library Update';
        final body = message.notification?.body ?? '';
        _showLocalNotification(title, body);
      });

      // User tapped the push while app was in background.
      FirebaseMessaging.onMessageOpenedApp.listen((_) {
        _navigateToNotifications();
      });

      // App was launched by tapping the push (terminated state).
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _navigateToNotifications();
      }
    }
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Updates from your library',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }

  void _navigateToNotifications() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = appNavigatorKey.currentContext;
      if (ctx != null) GoRouter.of(ctx).push('/notifications');
    });
  }

  /// Persists the device token on the student document for the given library.
  /// Called once the student has joined/verified, so the owner can push to it.
  ///
  /// Only `fcmTokens` is written here. The `authUid` device binding is set
  /// server-side by the `verifyStudentId` Cloud Function — the client can
  /// never set it (rules deny it), which prevents account takeovers.
  Future<void> registerToken(String ownerUid, String studentId) async {
    // Request permission now that the user is actually joining/verifying a library
    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

    final token = _currentFcmToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null || ownerUid.isEmpty || studentId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .collection('students')
          .doc(studentId)
          .set(
            {
              'fcmTokens': FieldValue.arrayUnion([token]),
            },
            SetOptions(merge: true),
          );
    } catch (_) {
      // Non-critical: token persistence failure should not break the app.
    }
  }

  /// Removes the device token from the student document (e.g. on leave/logout).
  Future<void> unregisterToken(String ownerUid, String studentId) async {
    final token = _currentFcmToken;
    if (token == null || ownerUid.isEmpty || studentId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .collection('students')
          .doc(studentId)
          .update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    } catch (_) {
      // Non-critical.
    }
  }
}
