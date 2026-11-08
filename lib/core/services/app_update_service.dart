import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_update/in_app_update.dart';

/// Wraps the `in_app_update` (Play Core) plugin so the app silently checks for
/// updates at launch and downloads them in the background using the FLEXIBLE
/// update flow — the user keeps using the app while the APK downloads, and a
/// downloaded update is completed (installed) when the app returns to the
/// foreground.
///
/// In-app updates only work on Android when the app is distributed through
/// Google Play (and only from API 21+). Every failure is swallowed so the
/// check can never affect startup or crash the app on unsupported setups
/// (debug builds, sideloaded APKs, iOS/web).
class AppUpdateService with WidgetsBindingObserver {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  bool _initialized = false;
  bool _checking = false;
  bool _completing = false;
  StreamSubscription<InstallStatus>? _installSub;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Registers the app-lifecycle observer, listens for a finished background
  /// download, and kicks off the launch-time check. Call once after `runApp`.
  void initialize() {
    if (_initialized) return;
    _initialized = true;
    if (!_isAndroid) return;
    WidgetsBinding.instance.addObserver(this);
    // Complete a flexible update the moment Play Core finishes downloading
    // it — the user sees the install prompt immediately, not only on the next
    // app resume. The resume path below remains as a safety net.
    _installSub?.cancel();
    _installSub = InAppUpdate.installUpdateListener.listen((status) {
      if (status == InstallStatus.downloaded) {
        unawaited(completePendingUpdate());
      }
    });
    unawaited(checkForUpdate());
  }

  /// Releases the update listener and lifecycle observer. Safe to call even
  /// when the service was never initialized.
  void dispose() {
    _installSub?.cancel();
    _installSub = null;
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
      _initialized = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A flexible update finishes downloading in the background; when the
    // user comes back to the app, complete it (shows the install dialog).
    if (state == AppLifecycleState.resumed) {
      unawaited(completePendingUpdate());
    }
  }

  /// Checks the Play Store for an update. If one is available it starts a
  /// flexible update (downloads in the background), falling back to an
  /// immediate update only when the Play Store blocks the flexible flow.
  Future<void> checkForUpdate() async {
    if (!_isAndroid || _checking) return;
    _checking = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }
      // Seamless FLEXIBLE update only: the APK downloads silently in the
      // background and the user is prompted to apply it once it's ready. We
      // deliberately never force an interrupting immediate update.
      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
      }
    } catch (_) {
      // Play Core not available (e.g. not installed via Google Play) — no-op.
    } finally {
      _checking = false;
    }
  }

  /// Installs a flexible update that finished downloading while the app was
  /// running. Safe to call on every resume — it no-ops when nothing is ready.
  Future<void> completePendingUpdate() async {
    if (!_isAndroid || _completing) return;
    _completing = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      final readyToInstall =
          info.installStatus == InstallStatus.downloaded ||
              info.updateAvailability ==
                  UpdateAvailability.developerTriggeredUpdateInProgress;
      if (readyToInstall) {
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (_) {
      // Not ready / not available — ignore.
    } finally {
      _completing = false;
    }
  }
}
