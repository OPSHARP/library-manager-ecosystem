import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/deep_link_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';class LibraryStudentApp extends ConsumerStatefulWidget {
  const LibraryStudentApp({super.key});

  @override
  ConsumerState<LibraryStudentApp> createState() => _LibraryStudentAppState();
}

class _LibraryStudentAppState extends ConsumerState<LibraryStudentApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StudentDeepLinkService.instance.start();
      // Navigate to the reset screen when a password-reset link arrives.
      StudentDeepLinkService.instance.pendingResetCode.addListener(_onResetLink);
    });
  }

  @override
  void dispose() {
    StudentDeepLinkService.instance.pendingResetCode.removeListener(_onResetLink);
    super.dispose();
  }

  void _onResetLink() {
    final code = StudentDeepLinkService.instance.pendingResetCode.value;
    if (code != null && code.isNotEmpty) {
      ref.read(routerProvider).go('/reset-password');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return CupertinoApp.router(
      title: 'Students Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.cupertinoDarkTheme,
      routerConfig: router,
      builder: (context, child) {
        return DefaultTextStyle(
          style: GoogleFonts.openSans(
            color: AppColors.label,
          ),
          child: child!,
        );
      },
    );
  }
}
