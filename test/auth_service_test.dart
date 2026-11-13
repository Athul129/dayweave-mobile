import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dayweave_mobile/services/auth_service.dart';

UserResponse _response() => UserResponse.fromJson({
      'id': 'user-1',
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'sam@example.com',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{'display_name': 'Sam'},
      'created_at': '2026-01-01T00:00:00.000Z',
    });

void main() {
  test('updates display name with trimmed metadata only', () async {
    UserAttributes? received;
    final service = AuthService(
      SupabaseClient('https://example.com', 'test-key'),
      updateUser: (attributes) async {
        received = attributes;
        return _response();
      },
    );

    final result = await service.updateDisplayName('  Sam Lee  ');

    expect(result.user?.id, 'user-1');
    expect(received?.data, {'display_name': 'Sam Lee'});
    expect(received?.email, isNull);
    expect(received?.password, isNull);
  });

  test('rejects empty and whitespace-only names', () {
    final service = AuthService(
      SupabaseClient('https://example.com', 'test-key'),
      updateUser: (_) async => _response(),
    );

    expect(() => service.updateDisplayName(''), throwsArgumentError);
    expect(() => service.updateDisplayName('   '), throwsArgumentError);
  });

  test('propagates update failures', () async {
    final failure = StateError('offline');
    final service = AuthService(
      SupabaseClient('https://example.com', 'test-key'),
      updateUser: (_) => Future<UserResponse>.error(failure),
    );

    await expectLater(service.updateDisplayName('Sam'), throwsA(same(failure)));
  });
}
