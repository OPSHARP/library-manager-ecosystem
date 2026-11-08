import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Ad configuration sourced from Firebase Remote Config.
///
/// Keys (with in-code fallbacks so the app still works offline or before the
/// first fetch completes):
///   `admob_app_id`          — AdMob app ID
///   `admob_interstitial_id` — interstitial ad unit ID
///
/// The in-code defaults below are the LIVE production IDs. The same values
/// are also stored in Remote Config so they can be changed without shipping
/// a new build.
class AdConfigService {
  AdConfigService._();

  static final AdConfigService instance = AdConfigService._();

  /// Live AdMob app ID.
  static const String defaultAppId =
      'ca-app-pub-6089131009548737~5021145932';

  /// Live interstitial ad unit ID.
  static const String defaultInterstitialId =
      'ca-app-pub-6089131009548737/8729556730';

  static const String _appIdKey = 'admob_app_id';
  static const String _interstitialKey = 'admob_interstitial_id';

  String _appId = defaultAppId;
  String _interstitialId = defaultInterstitialId;
  bool _fetched = false;

  String get appId => _appId;
  String get interstitialAdUnitId => _interstitialId;

  /// Fetches and activates ad settings from Remote Config. Safe to call any
  /// number of times and never throws — on any failure the live in-code
  /// defaults are used.
  Future<void> fetch() async {
    if (_fetched) return;
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setDefaults(const {
        _appIdKey: defaultAppId,
        _interstitialKey: defaultInterstitialId,
      });
      // Best-effort: a slow network must never block the caller.
      await remoteConfig.fetchAndActivate();
      _appId = remoteConfig.getString(_appIdKey).trim().isNotEmpty
          ? remoteConfig.getString(_appIdKey).trim()
          : defaultAppId;
      _interstitialId =
          remoteConfig.getString(_interstitialKey).trim().isNotEmpty
          ? remoteConfig.getString(_interstitialKey).trim()
          : defaultInterstitialId;
      _fetched = true;
    } catch (_) {
      // Keep the live defaults on any failure.
    }
  }
}
