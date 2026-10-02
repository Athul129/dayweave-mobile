import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

String authErrorMessage(Object error, {bool signingIn = false}) {
  if (error is SocketException || error.toString().toLowerCase().contains('socket')) {
    return 'Please check your internet connection and try again.';
  }
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (signingIn && (message.contains('invalid login') || message.contains('invalid credentials'))) {
      return 'Invalid login details. Please check your email and password.';
    }
    if (message.contains('email not confirmed')) return 'Please confirm your email before signing in.';
    if (message.contains('already registered')) return 'An account already exists for this email.';
    if (message.contains('password')) return 'Please choose a stronger password and try again.';
  }
  return signingIn ? 'Unable to sign in. Please check your details and try again.' : 'Unable to create your account. Please try again.';
}
