import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Central AdMob service for the student portal.
///
/// Responsibilities:
///  * Initialize the Mobile Ads SDK once, in the background — never block
///    the first frame on ad initialization.
///
/// Banners are managed by the [AdBanner] widget (see core/widgets/ad_banner.dart).
/// Interstitials are intentionally not used in this app to guarantee that at
/// most one ad (the banner) is ever visible at a time.
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  Future<void>? _initFuture;
  bool _sdkInitialized = false;

  /// Initializes the Mobile Ads SDK (idempotent). Never blocks startup on
  /// failure — callers can rely on the SDK being ready when ads are requested.
  Future<void> initialize() => _initFuture ??= _doInitialize();

  Future<void> _doInitialize() async {
    try {
      await MobileAds.instance.initialize();
      _sdkInitialized = true;
    } catch (_) {
      // Keep running; ad requests will simply no-op until init succeeds.
    }
  }

  /// Whether the Mobile Ads SDK has finished initializing.
  bool get isReady => _sdkInitialized;
}
