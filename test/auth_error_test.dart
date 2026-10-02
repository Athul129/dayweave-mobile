import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dayweave_mobile/features/auth/presentation/auth_error.dart';

void main() {
  test('maps invalid credentials without exposing the exception', () {
    final message = authErrorMessage(const AuthException('Invalid login credentials'), signingIn: true);
    expect(message, 'Invalid login details. Please check your email and password.');
    expect(message, isNot(contains('AuthException')));
  });

  test('maps network failures to a useful message', () {
    expect(authErrorMessage(const SocketException('offline')), contains('internet connection'));
  });

}
