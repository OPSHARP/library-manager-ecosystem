import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shows a modal bottom sheet that auto-dismisses when the app navigates to
/// another screen (route/location change). Prevents orphaned sheets that hold
/// disposed contexts, which cause "deactivated widget ancestor" / "Cannot use
/// ref after the widget was disposed" errors.
Future<T?> showAutoHideSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  final router = GoRouter.of(context);
  final navigator = Navigator.of(context);
  final initialLocation =
      router.routerDelegate.currentConfiguration.uri.toString();

  final future = showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor,
    shape: shape,
    builder: builder,
  );

  void listener() {
    final current = router.routerDelegate.currentConfiguration.uri.toString();
    if (current != initialLocation) {
      router.routerDelegate.removeListener(listener);
      if (navigator.mounted) navigator.pop();
    }
  }

  router.routerDelegate.addListener(listener);
  future.whenComplete(() => router.routerDelegate.removeListener(listener));
  return future;
}
