import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'app/app.dart';
import 'core/services/fcm_service.dart';
import 'core/services/app_update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firebase App Check (Play Integrity) — rejects unverified clients before
  // they can reach Firestore/Storage/Functions. Debug builds use the Debug
  // provider (register the printed debug token once in Firebase Console);
  // release builds use Play Integrity. Guarded so a stalled/unsupported App
  // Check can never block runApp (which would leave the app on the native
  // splash screen forever).
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
    ).timeout(const Duration(seconds: 4));
  } catch (_) {
    // Continue without App Check — Firestore rules + auth still protect data.
  }

  try {
    await FcmService.instance.init().timeout(const Duration(seconds: 3));
  } catch (_) {}

  // Android 15+ (targetSdk 35/36) renders edge-to-edge by default. Enable it
  // explicitly and use transparent system bars so the dark theme shows
  // through; Scaffold/SafeArea handle the insets on Android 15 and later.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0x00000000),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: LibraryStudentApp()));

  // Check for in-app updates (flexible background download on Play builds).
  AppUpdateService.instance.initialize();
}
