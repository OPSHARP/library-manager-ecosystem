import 'package:flutter/widgets.dart';

/// Root navigator key shared by the app widget and the GoRouter so
/// non-widget services (e.g. deep-link handling) can navigate without a
/// BuildContext.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
