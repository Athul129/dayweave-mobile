import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app_routes.dart';
import '../../features/auth/application/auth_session_provider.dart';
import '../../features/auth/presentation/auth_error.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/shell/presentation/mobile_shell.dart';
import '../../features/today/presentation/today_screen.dart';
import '../../features/week/presentation/this_week_screen.dart';
import '../../features/notes/presentation/loose_notes_screen.dart';
import '../../features/focus_history/presentation/focus_history_screen.dart';
import '../../services/providers.dart';

class _AuthRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = _AuthRefreshNotifier();
  ref.listen(authSessionProvider, (_, __) => authRefresh.refresh());
  ref.onDispose(authRefresh.dispose);
  final router = GoRouter(
    initialLocation: AppRoutes.today,
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final session = ref.read(authSessionProvider);
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' || location == '/loading';
      return switch (session) {
        AuthInitializing() => location == '/loading' ? null : '/loading',
        AuthSignedOut() => location == '/login' ? null : '/login',
        AuthSignedIn() => isAuthRoute ? AppRoutes.today : null,
        AuthSessionError() => location == '/auth-error' ? null : '/auth-error',
      };
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const _RouterLoadingScreen(),
      ),
      GoRoute(
        path: '/auth-error',
        builder: (context, state) => _RouterAuthErrorScreen(
          message: authErrorMessage(
              (ref.read(authSessionProvider) as AuthSessionError).error),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const AuthScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MobileShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.today,
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.week,
                builder: (context, state) => const ThisWeekScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.notes,
                builder: (context, state) => const LooseNotesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.focusHistory,
                builder: (context, state) => const FocusHistoryScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _RouterLoadingScreen extends StatelessWidget {
  const _RouterLoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image(
                image: AssetImage('assets/images/dayweave-mark.webp'),
                width: 72,
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
}

class _RouterAuthErrorScreen extends StatelessWidget {
  const _RouterAuthErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'We could not restore your session.\n\n$message',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}

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
