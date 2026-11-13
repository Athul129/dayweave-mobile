import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService(this._client,
      {Future<UserResponse> Function(UserAttributes)? updateUser})
      : _updateUser = updateUser;

  final SupabaseClient _client;
  final Future<UserResponse> Function(UserAttributes)? _updateUser;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signIn(
          {required String email, required String password}) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<AuthResponse> signUp(
          {required String email,
          required String password,
          required String displayName}) =>
      _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
        emailRedirectTo: 'dayweave://auth-callback',
      );

  Future<void> signOut() => _client.auth.signOut();

  Future<UserResponse> updateDisplayName(String displayName) {
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'Display name must not be empty.',
      );
    }

    final attributes = UserAttributes(data: {'display_name': trimmedName});
    return (_updateUser ?? _client.auth.updateUser)(attributes);
  }
}
