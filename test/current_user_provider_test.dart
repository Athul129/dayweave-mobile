import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dayweave_mobile/features/auth/application/current_user_provider.dart';
import 'package:dayweave_mobile/services/auth_service.dart';
import 'package:dayweave_mobile/services/providers.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService(this.user, this.events)
      : super(
          SupabaseClient(
            'https://example.com',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  User? user;
  final StreamController<AuthState> events;

  @override
  User? get currentUser => user;

  @override
  Stream<AuthState> get authStateChanges => events.stream;
}

User _user(String id) => User.fromJson({
      'id': id,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': '$id@example.com',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00.000Z',
    })!;

ProviderContainer _container(_FakeAuthService auth) => ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        authStateProvider.overrideWith((ref) => auth.authStateChanges),
      ],
    );

void main() {
  test('returns the authenticated user ID', () async {
    final events = StreamController<AuthState>.broadcast();
    final auth = _FakeAuthService(_user('user-a'), events);
    final container = _container(auth);
    addTearDown(() async {
      await events.close();
      container.dispose();
    });

    expect(container.read(currentUserIdProvider), 'user-a');
  });

  test('reacts to user updates, account switches, and sign out', () async {
    final events = StreamController<AuthState>.broadcast();
    final auth = _FakeAuthService(_user('user-a'), events);
    final container = _container(auth);
    addTearDown(() async {
      await events.close();
      container.dispose();
    });

    expect(container.read(currentUserIdProvider), 'user-a');

    auth.user = _user('user-b');
    events.add(AuthState(AuthChangeEvent.userUpdated, null));
    await container.pump();
    expect(container.read(currentUserIdProvider), 'user-b');

    auth.user = null;
    events.add(AuthState(AuthChangeEvent.signedOut, null));
    await container.pump();
    expect(container.read(currentUserIdProvider), isNull);
  });
}
