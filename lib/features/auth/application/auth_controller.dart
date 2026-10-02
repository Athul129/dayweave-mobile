import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/providers.dart';

final currentSessionProvider = Provider((ref) => ref.watch(authServiceProvider).currentSession);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authServiceProvider).signOut());
  }

  Future<AuthResponse> signIn({required String email, required String password}) =>
      ref.read(authServiceProvider).signIn(email: email, password: password);

  Future<AuthResponse> signUp({required String email, required String password, required String displayName}) =>
      ref.read(authServiceProvider).signUp(email: email, password: password, displayName: displayName);
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(AuthController.new);
