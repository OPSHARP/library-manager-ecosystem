import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'lemniscate_splash.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// Minimum time the loading screen must be visible (2 seconds).
  static const Duration _minDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _waitAndNavigate();
  }

  Future<void> _waitAndNavigate() async {
    final start = DateTime.now();

    // Wait until auth has finished initializing so navigation lands on the
    // correct screen (dashboard when logged in, auth otherwise). Bounded by a
    // safety timeout so the splash can never hang forever.
    var attempts = 0;
    while (ref.read(authProvider).isLoading && mounted && attempts < 100) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    // Ensure the loading screen stays visible for at least 5 seconds total.
    final elapsed = DateTime.now().difference(start);
    final remaining = _minDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (mounted) context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    return const LemniscateSplash();
  }
}
