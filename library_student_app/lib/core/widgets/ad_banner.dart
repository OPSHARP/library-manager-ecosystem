import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_config_service.dart';
import '../services/ad_service.dart';

/// Non-intrusive adaptive banner ad.
///
/// **Placement contract (AdMob UX policy):**
/// This widget is designed to live in a [Scaffold.bottomNavigationBar] slot.
/// The Scaffold lays the banner out in its own reserved strip *below* the body,
/// so it can never overlap buttons, links, form fields or any other
/// interactive element. Do not stack it inside the body or wrap it with
/// `Positioned`/`Stack` over content.
///
/// The banner:
///  * sizes itself dynamically to the device width + orientation
///    (anchored adaptive banner — no fixed-size clipping),
///  * is wrapped in `SafeArea(top: false)` so it never sits under the system
///    navigation bar in edge-to-edge mode,
///  * occupies zero space until an ad is actually loaded, so screens never
///    show an empty grey box,
///  * never throws — any load failure simply collapses the banner away.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  double? _lastWidth;
  Orientation? _lastOrientation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.sizeOf(context).width;
    final orientation = MediaQuery.orientationOf(context);
    if (width == _lastWidth && orientation == _lastOrientation) return;
    _lastWidth = width;
    _lastOrientation = orientation;
    _loadBanner(width);
  }

  /// Tracks whether the initial 30-second grace period has elapsed.
  static bool _startupDelayDone = false;
  static final Stopwatch _appTimer = Stopwatch()..start();

  Future<void> _loadBanner(double width) async {
    // Give the user 30 seconds of ad-free experience on app start.
    if (!_startupDelayDone) {
      final remaining = const Duration(seconds: 30) - _appTimer.elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
      _startupDelayDone = true;
    }
    if (!mounted) return;

    // Ensure the SDK is initialized first (idempotent, non-blocking).
    await AdService.instance.initialize();

    final old = _bannerAd;
    if (old != null) {
      old.dispose();
      _bannerAd = null;
    }
    if (!mounted) return;

    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width.round(),
    );
    if (size == null || !mounted) return; // adaptive size unavailable → no ad

    setState(() {
      _isLoaded = false;
    });

    final ad = BannerAd(
      adUnitId: AdConfigService.instance.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          // Only the CURRENT banner may flip the loaded flag. After an
          // orientation-change reload a stale ad's callback could otherwise
          // mark a not-yet-loaded banner as ready, and building an AdWidget
          // before its ad is loaded throws.
          if (mounted && identical(_bannerAd, ad)) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted && identical(_bannerAd, ad)) {
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
            });
          }
        },
      ),
    );
    _bannerAd = ad;
    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    // Render nothing until an ad is actually loaded → zero layout impact.
    if (ad == null || !_isLoaded) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        color: CupertinoColors.black,
        alignment: Alignment.center,
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
