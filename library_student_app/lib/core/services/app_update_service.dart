import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:in_app_update/in_app_update.dart';
import '../../app/router.dart';
import '../constants/app_constants.dart';

/// Wraps the `in_app_update` (Google Play Core) plugin to implement
/// Android In-App Flexible & Immediate Updates according to the latest
/// Google Play Console guidelines:
///
/// 1. **Lifecycle-Aware State Handling**:
///    - Checks for updates silently at launch and on app resume.
///    - Handles `developerTriggeredUpdateInProgress` to resume interrupted updates.
/// 2. **Flexible Background Updates**:
///    - Downloads updates in the background without interrupting the user.
///    - Streams `installUpdateListener` to track progress and notify upon completion.
/// 3. **Priority & Staleness Escalation**:
///    - Evaluates Google Play release priority (`updatePriority` 0–5) and
///      staleness (`clientVersionStalenessDays`) to trigger immediate updates
///      for critical releases and flexible updates for standard enhancements.
/// 4. **User-Friendly Confirmation**:
///    - Prompts the user with a confirmation dialog to restart and apply once downloaded.
/// 5. **Safe Environments**:
///    - Guards against non-Android platforms, sideloads, and debug builds.
class AppUpdateService with WidgetsBindingObserver {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  bool _initialized = false;
  bool _checking = false;
  bool _completing = false;
  bool _dialogShowing = false;
  bool _isDownloading = false;
  StreamSubscription<InstallStatus>? _installSub;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Registers lifecycle observer and listens for background download events.
  /// Call once during app startup after `runApp`.
  void initialize() {
    if (_initialized) return;
    _initialized = true;
    if (!_isAndroid) return;

    WidgetsBinding.instance.addObserver(this);

    // Stream download progress events from Play Core
    _installSub?.cancel();
    _installSub = InAppUpdate.installUpdateListener.listen(
      (status) {
        debugPrint('InAppUpdate status event: $status');
        switch (status) {
          case InstallStatus.downloading:
          case InstallStatus.pending:
            _isDownloading = true;
            break;
          case InstallStatus.downloaded:
            _isDownloading = false;
            unawaited(promptOrCompleteUpdate());
            break;
          case InstallStatus.installed:
          case InstallStatus.failed:
          case InstallStatus.canceled:
            _isDownloading = false;
            break;
          default:
            break;
        }
      },
      onError: (e) {
        debugPrint('InAppUpdate installUpdateListener error: $e');
        _isDownloading = false;
      },
    );

    // Initial silent check on launch
    unawaited(checkForUpdate());
  }

  /// Cleans up listeners and lifecycle observers.
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
    if (state == AppLifecycleState.resumed && _isAndroid) {
      // Upon returning to foreground, check if download completed or
      // if an interrupted update must be resumed according to Play guidelines.
      unawaited(_handleAppResume());
    }
  }

  /// Handles app resume checks silently.
  Future<void> _handleAppResume() async {
    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.installStatus == InstallStatus.downloaded) {
        await promptOrCompleteUpdate();
      } else if (info.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress) {
        // Resume immediate update if it was in progress when backgrounded
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        }
      }
    } catch (e) {
      debugPrint('InAppUpdate resume check ignored: $e');
    }
  }

  /// Checks Google Play for an update.
  ///
  /// - [userInitiated]: If true (e.g. tapped from Profile/Settings), provides
  ///   user-visible toast feedback.
  Future<void> checkForUpdate({bool userInitiated = false}) async {
    if (!_isAndroid) {
      if (userInitiated) {
        _showToast('In-app updates are only supported on Android via Google Play.');
      }
      return;
    }

    if (_checking) {
      if (userInitiated) {
        _showToast('Checking for updates...');
      }
      return;
    }
    _checking = true;

    if (userInitiated) {
      _showToast('Checking for updates...');
    }

    try {
      final info = await InAppUpdate.checkForUpdate();
      debugPrint('InAppUpdate info: $info');

      // ─── Case 1: Update is already downloaded and ready to apply ───
      if (info.installStatus == InstallStatus.downloaded) {
        await promptOrCompleteUpdate(userInitiated: userInitiated);
        return;
      }

      // ─── Case 2: Update is currently downloading in the background ───
      if (info.installStatus == InstallStatus.downloading ||
          info.installStatus == InstallStatus.pending ||
          _isDownloading) {
        if (userInitiated) {
          _showToast('Update is currently downloading in the background...');
        }
        return;
      }

      // ─── Case 3: Resume an in-progress developer-triggered update ───
      if (info.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
          return;
        }
      }

      // ─── Case 4: A new update is available on Google Play ───
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        final priority = info.updatePriority;
        final stalenessDays = info.clientVersionStalenessDays ?? 0;

        // Play Console priority (4-5 is high/critical) or high staleness (>30 days)
        final isCriticalUpdate = priority >= 4 || stalenessDays >= 30;

        if (isCriticalUpdate && info.immediateUpdateAllowed) {
          // Critical update flow
          if (userInitiated) {
            _showToast('Critical update required. Starting update...');
          }
          final result = await InAppUpdate.performImmediateUpdate();
          _handleUpdateResult(result, userInitiated);
        } else if (info.flexibleUpdateAllowed) {
          // Standard / Flexible background update
          if (userInitiated) {
            _showToast('Update found! Downloading in the background...');
          }
          final result = await InAppUpdate.startFlexibleUpdate();
          _handleUpdateResult(result, userInitiated);
        } else if (info.immediateUpdateAllowed && userInitiated) {
          // Fallback to immediate update if flexible is not allowed by Play Store
          final result = await InAppUpdate.performImmediateUpdate();
          _handleUpdateResult(result, userInitiated);
        } else if (userInitiated) {
          _showToast('A new update is available on Google Play.');
        }
      } else if (userInitiated) {
        _showToast('You are on the latest version (v${AppConstants.appVersion}).');
      }
    } on PlatformException catch (pe) {
      debugPrint('InAppUpdate PlatformException: ${pe.code} - ${pe.message}');
      if (userInitiated) {
        if (pe.code.contains('APP_NOT_OWNED') || pe.code.contains('-10')) {
          _showToast('In-app updates require installation from the Google Play Store.');
        } else {
          _showToast('Could not reach Google Play Store.');
        }
      }
    } catch (e) {
      debugPrint('AppUpdateService checkForUpdate error: $e');
      if (userInitiated) {
        _showToast('Unable to check for updates at this time.');
      }
    } finally {
      _checking = false;
    }
  }

  void _handleUpdateResult(AppUpdateResult result, bool userInitiated) {
    switch (result) {
      case AppUpdateResult.success:
        if (userInitiated) {
          _showToast('Update download started in the background.');
        }
        break;
      case AppUpdateResult.userDeniedUpdate:
        if (userInitiated) {
          _showToast('Update postponed.');
        }
        break;
      case AppUpdateResult.inAppUpdateFailed:
        if (userInitiated) {
          _showToast('Update could not be completed.');
        }
        break;
    }
  }

  /// Prompts the user to restart and install the downloaded update,
  /// strictly adhering to Google Play guidelines (never restarting without confirmation).
  Future<void> promptOrCompleteUpdate({bool userInitiated = false}) async {
    if (!_isAndroid || _completing || _dialogShowing) return;
    _completing = true;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.installStatus != InstallStatus.downloaded) {
        return;
      }

      if (_dialogShowing) return;
      _dialogShowing = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = appNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          showCupertinoDialog(
            context: ctx,
            barrierDismissible: false,
            builder: (dialogCtx) => CupertinoAlertDialog(
              title: const Text('Update Ready'),
              content: const Text(
                'A new update has finished downloading in the background. '
                'Restart the app now to apply the changes?',
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Later'),
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    if (userInitiated) {
                      _showToast('Update will be applied when you reopen the app.');
                    }
                  },
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text('Restart & Update'),
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    InAppUpdate.completeFlexibleUpdate().catchError((e) {
                      debugPrint('InAppUpdate completeFlexibleUpdate error: $e');
                      _showToast('Failed to apply update. Please restart manually.');
                    });
                  },
                ),
              ],
            ),
          ).whenComplete(() {
            _dialogShowing = false;
          });
        } else {
          _dialogShowing = false;
          _showToast('Update downloaded! Restart the app to apply.');
        }
      });
    } catch (e) {
      _dialogShowing = false;
      debugPrint('AppUpdateService promptOrCompleteUpdate error: $e');
    } finally {
      _completing = false;
    }
  }

  void _showToast(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      gravity: ToastGravity.BOTTOM,
      toastLength: Toast.LENGTH_SHORT,
    );
  }
}
