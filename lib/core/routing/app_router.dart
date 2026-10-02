import 'package:flutter/material.dart';
import 'app_routes.dart';

/// Central route names for future nested feature navigation.
///
/// Phase 2 uses the shell's selected destination rather than feature routes;
/// later phases can replace this with a RouterConfig without changing domain
/// repositories or theme code.
Route<dynamic>? dayweaveRouteFactory(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.today:
    case AppRoutes.week:
    case AppRoutes.notes:
    case AppRoutes.focusHistory:
      return null;
    default:
      return null;
  }
}
