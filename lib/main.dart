import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'app/app.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/offline_attendance_service.dart';
import 'core/services/ad_service.dart';
import 'core/services/app_update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android 15+ renders edge-to-edge by default (targetSdk 35/36). Enable it
  // explicitly and make the system bars transparent so the dark theme paints
  // behind them; Scaffold/SafeArea handle the insets so content never
  // overlaps the status bar or gesture navigation bar.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firebase App Check (Play Integrity) — rejects unverified clients before
  // they can reach Firestore/Storage/Functions. Debug builds use the Debug
  // provider (register the printed debug token once in Firebase Console →
  // App Check → Apps); release builds use Play Integrity automatically.
  // Guarded so a stalled/unsupported App Check can never block runApp (which
  // would leave the app on the native splash screen forever).
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
    );
  } catch (_) {
    // Continue without App Check — Firestore rules + auth still protect data.
  }

  // Initialize connectivity monitoring early
  ConnectivityService.instance.initialize();
  OfflineAttendanceService.instance.init();

  // Initialize AdMob in the background — never block the first frame on the
  // SDK's network-bound startup (that would hold the native splash screen and
  // show a black screen for several seconds). The interstitial ad unit ID is
  // loaded from Firebase Remote Config; ads are gated by the Pro subscription
  // and only shown at compliant moments (throttled, never at launch).
  unawaited(AdService.instance.initialize());

  runApp(const ProviderScope(child: LibraryManagerApp()));

  // Check for in-app updates (flexible background download on Play builds).
  AppUpdateService.instance.initialize();
}
