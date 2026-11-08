import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/auth/presentation/screens/reset_password_screen.dart';
import '../features/auth/presentation/screens/welcome_screen.dart';
import '../features/auth/presentation/screens/qr_scanner_screen.dart';
import '../features/auth/presentation/screens/profile_create_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/seats/seat_layout_screen.dart';
import '../features/books/my_books_screen.dart';
import '../features/fees/fee_details_screen.dart';
import '../features/attendance/attendance_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/profile_edit_screen.dart';
import '../features/profile/privacy_policy_screen.dart';
import '../features/profile/terms_of_use_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/libraries/presentation/screens/nearby_libraries_screen.dart';
import '../features/libraries/presentation/screens/library_preview_screen.dart';
import 'main_nav_screen.dart';

/// Global navigator key so FCM push handlers (outside the widget tree) can
/// navigate to the notifications screen when a notification is tapped.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

final splashDelayProvider = StateNotifierProvider<SplashDelayNotifier, bool>((ref) {
  return SplashDelayNotifier();
});

class SplashDelayNotifier extends StateNotifier<bool> {
  SplashDelayNotifier() : super(true) {
    // Short brand splash — kept brief so the app reaches the home screen fast.
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) state = false;
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/splash',
    // Never show a blank white screen on a routing error — render a visible
    // message (with the error logged for diagnosis) instead of an empty frame.
    errorBuilder: (context, state) => const _RouteErrorScreen(),
    redirect: (context, state) {
      // Read the latest auth state fresh on every evaluation. We deliberately
      // do NOT `ref.watch` here — that would recreate the whole router on
      // every auth change. `ref.listen` below calls router.refresh() instead.
      final auth = ref.read(authProvider);
      final isSplashDelaying = ref.read(splashDelayProvider);
      if (auth.isLoading || isSplashDelaying) return null;
      final loc = state.uri.toString();

      // Once auth has loaded, leave the splash screen for the right place.
      if (loc == '/splash') {
        if (!auth.isAuthenticated) return '/auth';
        if (!auth.hasProfile) return '/profile-create';
        return '/dashboard';
      }

      // An authenticated user must never stay on the auth screen — forward
      // them to the next incomplete step.
      if (loc == '/auth') {
        if (auth.isAuthenticated) {
          if (!auth.hasProfile) return '/profile-create';
          return '/dashboard';
        }
        return null; // signed out → the auth screen is the right place
      }

      // Truly public routes that anyone can view (including while signed out)
      if (loc == '/privacy' || loc == '/terms' || loc == '/reset-password') {
        return null;
      }

      // Everything else requires authentication
      if (!auth.isAuthenticated) return '/auth';

      // At this point, the user IS authenticated.
      // Allow access to setup screens and profile without forcing them to the dashboard yet.
      final setupRoutes = ['/profile-create', '/qr-scanner', '/welcome', '/profile', '/library-preview', '/nearby-libraries'];
      if (setupRoutes.contains(loc)) return null;

      // If they are trying to access dashboard/main app, enforce profile existence
      if (!auth.hasProfile) return '/profile-create';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(name: 'auth', path: '/auth', builder: (_, _) => const AuthScreen()),
      GoRoute(name: 'reset-password', path: '/reset-password', builder: (_, _) => const ResetPasswordScreen()),
      GoRoute(name: 'welcome', path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(name: 'profile-create', path: '/profile-create', builder: (_, _) => const ProfileCreateScreen()),
      GoRoute(name: 'qr-scanner', path: '/qr-scanner', builder: (_, _) => const QrScannerScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: 'nearby',
                path: '/nearby-libraries',
                builder: (_, _) => const NearbyLibrariesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: 'profile',
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/seat-layout', builder: (_, _) => const SeatLayoutScreen()),
      GoRoute(path: '/books', builder: (_, _) => const MyBooksScreen()),
      GoRoute(path: '/fees', builder: (_, _) => const FeeDetailsScreen()),
      GoRoute(path: '/attendance', builder: (_, _) => const AttendanceScreen()),
      GoRoute(name: 'privacy', path: '/privacy', builder: (_, _) => const PrivacyPolicyScreen()),
      GoRoute(name: 'terms', path: '/terms', builder: (_, _) => const TermsOfUseScreen()),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(name: 'profile-edit', path: '/profile-edit', builder: (_, _) => const ProfileEditScreen()),
      GoRoute(
        path: '/library-preview',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>? ?? {};
          return LibraryPreviewScreen(registryData: data);
        },
      ),
    ],
  );

  // Re-evaluate redirects when auth state changes — without rebuilding the
  // router (which would reset to /splash and tear down in-flight navigation).
  ref.listen(authProvider, (_, _) => router.refresh());
  ref.listen(splashDelayProvider, (_, _) => router.refresh());

  return router;
});

/// Fallback shown when a route fails to build — a visible message instead of
/// a blank white frame, so release-mode failures are diagnosable.
class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      backgroundColor: Color(0xFF000000),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Something went wrong. Please reopen the app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8E8E93)),
            ),
          ),
        ),
      ),
    );
  }
}
