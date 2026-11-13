import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dayweave_mobile/features/account/presentation/account_avatar_action.dart';
import 'package:dayweave_mobile/features/auth/application/current_user_provider.dart';
import 'package:dayweave_mobile/services/auth_service.dart';
import 'package:dayweave_mobile/services/providers.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService(this.user, this._update)
      : events = StreamController<AuthState>.broadcast(),
        super(_testClient());

  User? user;
  final Future<UserResponse> Function(String) _update;
  final StreamController<AuthState> events;

  @override
  User? get currentUser => user;

  @override
  Stream<AuthState> get authStateChanges => events.stream;

  @override
  Future<UserResponse> updateDisplayName(String displayName) =>
      _update(displayName);
}

User _user({String name = 'Sam Lee', String id = 'user-1'}) => User.fromJson({
      'id': id,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'sam@example.com',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{'display_name': name},
      'created_at': '2026-01-01T00:00:00.000Z',
    })!;

UserResponse _response(User user) => UserResponse.fromJson(user.toJson());

SupabaseClient _testClient() => SupabaseClient(
      'https://example.com',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

Widget _app({required User user, required AuthService auth}) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(user),
        authServiceProvider.overrideWithValue(auth),
      ],
      child: const MaterialApp(
        home: Scaffold(body: AccountAvatarAction(onSignOut: _noop)),
      ),
    );

Widget _reactiveApp(_FakeAuthService auth) => ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        authStateProvider.overrideWith((ref) => auth.authStateChanges),
      ],
      child: const MaterialApp(
        home: Scaffold(body: AccountAvatarAction(onSignOut: _noop)),
      ),
    );

void _noop() {}

void main() {
  testWidgets('opens Edit Profile with name and read-only email',
      (tester) async {
    final user = _user();
    final auth = AuthService(
      _testClient(),
      updateUser: (_) async => _response(user),
    );
    await tester.pumpWidget(_app(user: user, auth: auth));
    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(find.text('Sam Lee'), findsOneWidget);
    final emailField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(emailField.controller!.text, 'sam@example.com');
    expect(emailField.enabled, isFalse);
    expect(find.text('Edit profile'), findsOneWidget);
  });

  testWidgets('rejects blank input without saving', (tester) async {
    var calls = 0;
    final user = _user();
    final auth = AuthService(
      _testClient(),
      updateUser: (_) async {
        calls++;
        return _response(user);
      },
    );
    await tester.pumpWidget(_app(user: user, auth: auth));
    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter a display name.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('failed save preserves input and allows retry', (tester) async {
    final user = _user();
    var attempts = 0;
    final auth = AuthService(
      _testClient(),
      updateUser: (_) {
        attempts++;
        if (attempts == 1)
          return Future<UserResponse>.error(StateError('offline'));
        return Future.value(_response(user));
      },
    );
    await tester.pumpWidget(_app(user: user, auth: auth));
    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).first;
    await tester.enterText(field, '  Taylor  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to save your profile. Please try again.'),
        findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, '  Taylor  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsNothing);
    expect(attempts, 2);
  });

  testWidgets('trims the submitted display name', (tester) async {
    final user = _user();
    String? submitted;
    var calls = 0;
    final auth = AuthService(
      _testClient(),
      updateUser: (attributes) async {
        calls++;
        submitted = (attributes.data as Map<String, dynamic>)['display_name'];
        return _response(user);
      },
    );
    await tester.pumpWidget(_app(user: user, auth: auth));
    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '  Taylor  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(submitted, 'Taylor');
    expect(calls, 1);
  });

  testWidgets('shows Saving and prevents duplicate submissions',
      (tester) async {
    final user = _user();
    final pending = Completer<UserResponse>();
    var attempts = 0;
    final auth = AuthService(
      _testClient(),
      updateUser: (_) {
        attempts++;
        return pending.future;
      },
    );
    await tester.pumpWidget(_app(user: user, auth: auth));
    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Saving...'), findsOneWidget);
    final saveButton = find.ancestor(
      of: find.text('Saving...'),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    final cancelButton = find.ancestor(
      of: find.text('Cancel'),
      matching: find.byType(TextButton),
    );
    expect(tester.widget<TextButton>(cancelButton).onPressed, isNull);
    await tester.tap(find.text('Saving...'));
    expect(attempts, 1);
    pending.complete(_response(user));
    await tester.pumpAndSettle();
  });

  testWidgets('reacts to account switching while saving', (tester) async {
    final first = _user();
    final second = _user(name: 'Taylor Jones', id: 'user-2');
    final pending = Completer<UserResponse>();
    final auth = _FakeAuthService(first, (_) => pending.future);
    await tester.pumpWidget(_reactiveApp(auth));
    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();

    auth.user = second;
    auth.events.add(const AuthState(AuthChangeEvent.userUpdated, null));
    await tester.pump();
    await tester.pump();
    expect(find.text('Edit profile'), findsNothing);

    pending.complete(_response(first));
    await tester.pump();
    expect(find.text('Edit profile'), findsNothing);
    expect(find.text('TJ'), findsOneWidget);
    await auth.events.close();
  });

  testWidgets('dismisses safely when the account signs out', (tester) async {
    final user = _user();
    final auth = _FakeAuthService(user, (_) async => _response(user));
    addTearDown(auth.events.close);
    await tester.pumpWidget(_reactiveApp(auth));
    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    auth.user = null;
    auth.events.add(const AuthState(AuthChangeEvent.signedOut, null));
    await tester.pump();
    await tester.pump();
    expect(find.text('Edit profile'), findsNothing);
    expect(find.byTooltip('Account options'), findsNothing);
  });

  testWidgets('refreshes account identity after userUpdated', (tester) async {
    final first = _user();
    final updated = _user(name: 'Taylor Jones');
    late _FakeAuthService auth;
    auth = _FakeAuthService(first, (_) async {
      auth.user = updated;
      auth.events.add(
        AuthState(AuthChangeEvent.userUpdated, _sessionFor(updated)),
      );
      return _response(updated);
    });
    addTearDown(auth.events.close);
    await tester.pumpWidget(_reactiveApp(auth));
    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Edit profile'), findsNothing);
    expect(find.text('TJ'), findsOneWidget);
    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    expect(find.text('Taylor Jones'), findsOneWidget);
  });
}

Session _sessionFor(User user) => Session(
      accessToken: 'test-access-token',
      refreshToken: 'test-refresh-token',
      tokenType: 'bearer',
      user: user,
    );
