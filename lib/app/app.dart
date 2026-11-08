import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'router.dart';
import '../core/theme/app_theme.dart';
import '../core/l10n/app_localizations.dart';
import '../core/services/ad_service.dart';
import '../core/services/deep_link_service.dart';
import '../core/widgets/biometric_lock_gate.dart';
import '../features/settings/presentation/providers/settings_provider.dart';
import '../features/subscription/presentation/providers/subscription_provider.dart';

Locale _localeFromLanguage(String language) {
  switch (language) {
    case 'Hindi':   return const Locale('hi');
    case 'Spanish':  return const Locale('es');
    case 'French':   return const Locale('fr');
    case 'Arabic':   return const Locale('ar');
    case 'Portuguese': return const Locale('pt');
    case 'Chinese':  return const Locale('zh');
    case 'Japanese': return const Locale('ja');
    case 'Korean':   return const Locale('ko');
    case 'Turkish':  return const Locale('tr');
    case 'Russian':  return const Locale('ru');
    case 'German':   return const Locale('de');
    case 'Vietnamese': return const Locale('vi');
    case 'Thai':     return const Locale('th');
    case 'Malay':    return const Locale('ms');
    default:         return const Locale('en');
  }
}

/// Main App Widget
///
/// Always uses MaterialApp.router — the router handles auth redirects
/// (/auth when logged out, /dashboard when logged in). This avoids
/// swapping between two different widget trees on auth state changes,
/// which caused AnimatedBuilder errors from disposed widgets.
class LibraryManagerApp extends ConsumerStatefulWidget {
  const LibraryManagerApp({super.key});

  @override
  ConsumerState<LibraryManagerApp> createState() => _LibraryManagerAppState();
}

class _LibraryManagerAppState extends ConsumerState<LibraryManagerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDeepLinks();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Show a throttled interstitial when the user returns to the app — a
    // natural break, never at launch (AdService enforces a minimum session
    // age and a cooldown). Pro subscribers never see ads.
    if (state == AppLifecycleState.resumed) {
      _maybeShowInterstitial();
    }
  }

  void _maybeShowInterstitial() {
    final isPro =
        ref.read(subscriptionStatusProvider) == SubscriptionStatus.active;
    if (isPro) return;
    AdService.instance.showInterstitial();
  }

  void _initDeepLinks() {
    final deepLinks = DeepLinkService.instance;
    deepLinks.start();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    final settings = ref.watch(settingsProvider);
    final locale = _localeFromLanguage(settings.language);

    return MaterialApp.router(
      title: 'Library Manager and Owner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('es'),
        Locale('fr'),
        Locale('ar'),
        Locale('pt'),
        Locale('zh'),
        Locale('ja'),
        Locale('ko'),
        Locale('tr'),
        Locale('ru'),
        Locale('de'),
        Locale('vi'),
        Locale('th'),
        Locale('ms'),
      ],
      locale: locale,
      routerConfig: router,
      builder: (context, child) => BiometricLockGate(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
