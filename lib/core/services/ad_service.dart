import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config_service.dart';

/// Central AdMob service (interstitial ads only).
///
/// * The interstitial ad unit ID comes from Firebase Remote Config
///   ([AdConfigService]) — never a hardcoded test ID.
/// * The AdMob app ID is set in `AndroidManifest.xml` (required by the SDK).
/// * AdMob policy: the interstitial is never shown at app launch, is throttled
///   with a cooldown, and only after a foreground-resume event (a natural
///   break).
/// * Ads stop automatically for Pro subscribers (verified purchase).
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  static const Duration _interstitialCooldown = Duration(minutes: 2);

  /// No interstitial may show during the first moments of a session
  /// (AdMob policy — interstitials must not appear at app launch).
  static const Duration _minSessionAge = Duration(seconds: 45);

  Future<void>? _initFuture;
  bool _sdkInitialized = false;
  bool _interstitialLoading = false;
  InterstitialAd? _interstitial;
  DateTime _lastInterstitialShown = DateTime.fromMillisecondsSinceEpoch(0);
  final DateTime _appStart = DateTime.now();

  /// Initializes the Mobile Ads SDK (idempotent). Never blocks startup on
  /// failure — callers can rely on the SDK being ready when ads are requested.
  Future<void> initialize() => _initFuture ??= _doInitialize();

  Future<void> _doInitialize() async {
    try {
      // Fetch the live interstitial ad unit ID from Remote Config first
      // (the default is the live ID).
      await AdConfigService.instance.fetch();
      await MobileAds.instance.initialize();
      _sdkInitialized = true;
    } catch (_) {
      // Keep running; ad requests will simply no-op until init succeeds.
    }
  }

  bool get _sdkReady => _sdkInitialized;

  bool _withinCooldown() =>
      DateTime.now().difference(_lastInterstitialShown) < _interstitialCooldown;

  /// Loads and shows an interstitial when allowed. The caller is responsible
  /// for the Pro-subscription gate; this method additionally enforces:
  ///   * SDK ready
  ///   * app has been running at least [_minSessionAge] (no launch ad)
  ///   * cooldown between interstitials
  Future<void> showInterstitial() async {
    if (!_sdkReady) return;
    if (DateTime.now().difference(_appStart) < _minSessionAge) return;
    if (_withinCooldown()) return;
    if (_interstitialLoading) return;

    _interstitialLoading = true;
    try {
      final adUnitId = AdConfigService.instance.interstitialAdUnitId;
      _interstitial?.dispose();
      _interstitial = null;

      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitial = ad;
            _lastInterstitialShown = DateTime.now();
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                if (_interstitial == ad) _interstitial = null;
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                if (_interstitial == ad) _interstitial = null;
              },
            );
            ad.show();
          },
          onAdFailedToLoad: (error) {
            _interstitial = null;
          },
        ),
      );
    } catch (_) {
      // Never crash on ad load failures.
    } finally {
      _interstitialLoading = false;
    }
  }
}
