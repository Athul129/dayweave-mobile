import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dayweave_mobile/core/routing/app_router.dart';
import 'package:dayweave_mobile/features/auth/application/auth_session_provider.dart';
import 'package:dayweave_mobile/features/auth/application/current_user_provider.dart';
import 'package:dayweave_mobile/features/auth/presentation/auth_screen.dart';
import 'package:dayweave_mobile/features/weather/application/weather_controller.dart';
import 'package:dayweave_mobile/features/weather/application/weather_state.dart';
import 'package:dayweave_mobile/services/providers.dart';

final _testAuthSessionStateProvider =
    StateProvider<AuthSessionState>((ref) => const AuthInitializing());

class _FakeWeatherController extends WeatherController {
  @override
  WeatherState build() => const WeatherState();

  @override
  Future<void> load() async {}

  @override
  Future<void> refreshIfNeeded({DateTime? now, bool force = false}) async {}
}

User _user() => User.fromJson({
      'id': 'router-test-user',
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'router@example.com',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00.000Z',
    })!;

Session _session() => Session(
      accessToken: 'test-access-token',
      refreshToken: 'test-refresh-token',
      tokenType: 'bearer',
      user: _user(),
    );

ProviderScope _scope({required AuthSessionState auth}) => ProviderScope(
      overrides: [
        authSessionProvider.overrideWithValue(auth),
        currentUserProvider.overrideWithValue(null),
        currentUserIdProvider.overrideWithValue(null),
        supabaseClientProvider.overrideWithValue(
          SupabaseClient(
            'https://example.supabase.co',
            'test-anon-key',
            authOptions: const FlutterAuthClientOptions(
              autoRefreshToken: false,
            ),
          ),
        ),
        weatherProvider.overrideWith(_FakeWeatherController.new),
      ],
      child: const _RouterHost(),
    );

class _RouterHost extends ConsumerWidget {
  const _RouterHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        routerConfig: ref.watch(appRouterProvider),
      );
}

Future<void> _sendBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('authenticated router starts on Today and switches branches',
      (tester) async {
    await tester.pumpWidget(_scope(auth: AuthSignedIn(_session())));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));

    for (final label in ['Week', 'Notes', 'History', 'Today']) {
      await tester.tap(find.text(label).last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('unauthenticated router redirects to Login', (tester) async {
    await tester.pumpWidget(_scope(auth: const AuthSignedOut()));
    await tester.pump();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('authentication initialization uses the loading route',
      (tester) async {
    await tester.pumpWidget(_scope(auth: const AuthInitializing()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('auth session transitions refresh the router', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => ref.watch(_testAuthSessionStateProvider),
        ),
        supabaseClientProvider.overrideWithValue(
          SupabaseClient(
            'https://example.supabase.co',
            'test-anon-key',
            authOptions: const FlutterAuthClientOptions(
              autoRefreshToken: false,
            ),
          ),
        ),
        weatherProvider.overrideWith(_FakeWeatherController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _RouterHost(),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    container.read(_testAuthSessionStateProvider.notifier).state =
        const AuthSignedOut();
    await tester.pump();
    await tester.pump();
    final firstLoginScreen = find.byType(AuthScreen).last;
    expect(
      find.descendant(
        of: firstLoginScreen,
        matching: find.widgetWithText(FilledButton, 'Sign in'),
      ),
      findsOneWidget,
    );

    container.read(_testAuthSessionStateProvider.notifier).state =
        AuthSignedIn(_session());
    await tester.pump();
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);

    container.read(_testAuthSessionStateProvider.notifier).state =
        const AuthSignedOut();
    await tester.pump();
    await tester.pump();
    final finalLoginScreen = find.byType(AuthScreen).last;
    expect(
      find.descendant(
        of: finalLoginScreen,
        matching: find.widgetWithText(FilledButton, 'Sign in'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('root non-Today branches return to Today on Back',
      (tester) async {
    await tester.pumpWidget(_scope(auth: AuthSignedIn(_session())));
    await tester.pump(const Duration(milliseconds: 500));

    for (final label in ['Week', 'Notes', 'History']) {
      await tester.tap(find.text(label).last);
      await tester.pump();
      await _sendBack(tester);

      final navigationBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigationBar.selectedIndex, 0,
          reason: '$label should return to Today');
    }
  });

  testWidgets('Back from Today shows one logout dialog and Cancel stays',
      (tester) async {
    await tester.pumpWidget(_scope(auth: AuthSignedIn(_session())));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump();

    expect(find.text('Do you want to logout?'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(find.text('Do you want to logout?'), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });
}
