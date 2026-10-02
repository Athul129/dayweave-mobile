import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/providers.dart';

sealed class AuthSessionState {
  const AuthSessionState();
}

class AuthInitializing extends AuthSessionState {
  const AuthInitializing();
}

class AuthSignedOut extends AuthSessionState {
  const AuthSignedOut();
}

class AuthSignedIn extends AuthSessionState {
  const AuthSignedIn(this.session);
  final Session session;
  User get user => session.user;
}

class AuthSessionError extends AuthSessionState {
  const AuthSessionError(this.error);
  final Object error;
}

final authSessionProvider = Provider<AuthSessionState>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    loading: () => const AuthInitializing(),
    error: (error, stackTrace) => AuthSessionError(error),
    data: (state) => state.session == null ? const AuthSignedOut() : AuthSignedIn(state.session!),
  );
});
