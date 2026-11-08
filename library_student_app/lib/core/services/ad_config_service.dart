import 'package:flutter/foundation.dart';

/// Central AdMob configuration for the student portal.
///
/// ⚠️ DEVELOPMENT CONFIG — these are Google's official **TEST** ad unit IDs.
/// They always serve test ads on any device and can never generate revenue.
///
/// BEFORE SUBMITTING TO THE PLAY STORE:
///  * Replace `bannerAdUnitId` and `interstitialAdUnitId` with the real unit
///    IDs from your AdMob console.
///  * Replace the App ID in `android/app/src/main/AndroidManifest.xml` and
///    `ios/Runner/Info.plist` with your production App ID.
///
/// Keep ad unit IDs in one place so release swaps are a one-file change.
class AdConfigService {
  AdConfigService._();

  static final AdConfigService instance = AdConfigService._();

  /// Google's official TEST App ID (Android). The matching value is also
  /// declared in `AndroidManifest.xml` (the Mobile Ads SDK requires it there).
  static const String defaultAndroidAppId =
      'ca-app-pub-3940256099942544~3347511713';

  /// Google's official TEST App ID (iOS), declared in `Info.plist`.
  static const String defaultIosAppId =
      'ca-app-pub-3940256099942544~1458002511';

  /// TEST adaptive/anchored banner ad unit ID.
  static const String defaultBannerId =
      'ca-app-pub-3940256099942544/6300978111';

  /// TEST interstitial ad unit ID.
  static const String defaultInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';

  String get appId =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
          ? defaultIosAppId
          : defaultAndroidAppId;

  String get bannerAdUnitId => defaultBannerId;

  String get interstitialAdUnitId => defaultInterstitialId;
}
