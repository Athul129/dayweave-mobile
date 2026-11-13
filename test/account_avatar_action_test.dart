import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dayweave_mobile/features/account/presentation/account_avatar_action.dart';
import 'package:dayweave_mobile/features/auth/application/current_user_provider.dart';

User _user({String? displayName, String email = 'sam@example.com'}) =>
    User.fromJson({
      'id': 'user-1',
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': email,
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{
        if (displayName != null) 'display_name': displayName,
      },
      'created_at': '2026-01-01T00:00:00.000Z',
    })!;

final testUserProvider = StateProvider<User?>((ref) => null);

Widget _app(User? user, {VoidCallback? onSignOut}) => ProviderScope(
      overrides: [
        testUserProvider.overrideWith((ref) => user),
        currentUserProvider.overrideWith((ref) => ref.watch(testUserProvider)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: AccountAvatarAction(onSignOut: onSignOut ?? _noop),
        ),
      ),
    );

void _noop() {}

void main() {
  test('generates initials for single and multiple word names', () {
    expect(accountInitials('Sam Lee'), 'SL');
    expect(accountInitials('Sam'), 'SA');
    expect(accountInitials(''), '');
    expect(accountInitials('sam'), 'SA');
    expect(accountInitials('Sam.Example'), 'SE');
    expect(accountInitials('sam+test'), 'ST');
  });

  testWidgets('displays authenticated name, email, and initials',
      (tester) async {
    await tester.pumpWidget(_app(_user(displayName: 'Sam Lee')));
    expect(find.text('SL'), findsOneWidget);

    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    expect(find.text('Sam Lee'), findsOneWidget);
    expect(find.text('sam@example.com'), findsOneWidget);
  });

  testWidgets('falls back to email when display name is missing',
      (tester) async {
    await tester.pumpWidget(_app(_user()));
    expect(find.text('SA'), findsOneWidget);

    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    expect(find.text('sam@example.com'), findsNWidgets(2));
  });

  testWidgets('whitespace display name falls back to email local initials',
      (tester) async {
    await tester.pumpWidget(_app(_user(displayName: '   ')));
    expect(find.text('SA'), findsOneWidget);
  });

  testWidgets('updates when the authenticated user changes', (tester) async {
    await tester.pumpWidget(_app(_user(displayName: 'Sam Lee')));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AccountAvatarAction)),
    );
    expect(find.text('SL'), findsOneWidget);

    container.read(testUserProvider.notifier).state =
        _user(displayName: 'Taylor Jones', email: 'taylor@example.com');
    await tester.pump();
    expect(find.text('TJ'), findsOneWidget);
  });

  testWidgets('hides the account control after sign out', (tester) async {
    await tester.pumpWidget(_app(_user(displayName: 'Sam Lee')));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AccountAvatarAction)),
    );
    container.read(testUserProvider.notifier).state = null;
    await tester.pump();
    expect(find.byTooltip('Account options'), findsNothing);
  });

  testWidgets('selecting Sign out invokes the supplied callback',
      (tester) async {
    var signedOut = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_user(displayName: 'Sam Lee')),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AccountAvatarAction(onSignOut: () => signedOut = true),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    expect(signedOut, isTrue);
  });

  testWidgets('does not show account identity when signed out', (tester) async {
    await tester.pumpWidget(_app(null));
    expect(find.byType(PopupMenuButton), findsNothing);
    expect(find.byTooltip('Account options'), findsNothing);
  });
}
