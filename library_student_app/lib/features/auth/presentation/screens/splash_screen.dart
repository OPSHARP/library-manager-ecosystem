import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/lemniscate_splash.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authProvider, (prev, next) {
      // Router redirect handles navigation
    });
    return const CupertinoPageScaffold(
      child: LemniscateSplash(
        title: 'Students Portal',
        tag: 'LIBRARY MANAGEMENT',
      ),
    );
  }
}
