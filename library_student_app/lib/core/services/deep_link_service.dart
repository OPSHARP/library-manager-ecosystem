import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Handles Firebase Auth password-reset deep links (Android App Links) so a
/// student tapping the reset link in their email opens THIS (Students Portal)
/// app and is taken straight to the in-app "set new password" screen.
class StudentDeepLinkService {
  StudentDeepLinkService._();

  static final StudentDeepLinkService instance = StudentDeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  final ValueNotifier<String?> pendingResetCode = ValueNotifier<String?>(null);
  StreamSubscription<Uri>? _subscription;
  bool _started = false;

  /// Extracts a Firebase password-reset `oobCode` from a link URI.
  ///
  /// Firebase action links look like:
  ///   `https://<domain>/__/auth/action?mode=resetPassword&oobCode=...&apiKey=...`
  static String? parseResetCode(Uri uri) {
    final mode = uri.queryParameters['mode'];
    final oobCode = uri.queryParameters['oobCode'];
    if ((mode == 'resetPassword' || uri.path.contains('reset')) &&
        oobCode != null &&
        oobCode.isNotEmpty) {
      return Uri.decodeComponent(oobCode);
    }
    return null;
  }

  /// Starts listening for deep links. Safe to call more than once.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Cold start — the link that launched the app.
    try {
      final initial = await _appLinks.getInitialLink();
      final code = initial == null ? null : parseResetCode(initial);
      if (code != null && pendingResetCode.value == null) {
        pendingResetCode.value = code;
      }
    } catch (_) {}

    // Warm start / while the app is running.
    _subscription = _appLinks.uriLinkStream.listen((uri) {
      final code = parseResetCode(uri);
      if (code != null) {
        pendingResetCode.value = code;
      }
    });
  }

  /// Consumes the pending reset code (call after the reset screen reads it so
  /// the same link is not handled twice).
  void clear() {
    pendingResetCode.value = null;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _started = false;
    pendingResetCode.dispose();
  }
}