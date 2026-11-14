import 'dart:async';

import 'package:dayweave_mobile/core/date_time/dayweave_date_time.dart';
import 'package:dayweave_mobile/features/auth/application/current_user_provider.dart';
import 'package:dayweave_mobile/features/focus_history/application/focus_history_controller.dart';
import 'package:dayweave_mobile/features/focus_history/presentation/focus_history_screen.dart';
import 'package:dayweave_mobile/models/domain_models.dart';
import 'package:dayweave_mobile/repositories/focus_repository.dart';
import 'package:dayweave_mobile/services/auth_service.dart';
import 'package:dayweave_mobile/services/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class _FakeFocusRepository implements FocusRepository {
  _FakeFocusRepository(this.byUser);

  final Map<String, List<FocusSession>> byUser;
  final List<String> requestedUserIds = [];
  Completer<List<FocusSession>>? pending;

  @override
  Future<List<FocusSession>> fetchForUser(String userId) {
    requestedUserIds.add(userId);
    final pendingResponse = pending;
    if (pendingResponse != null) return pendingResponse.future;
    return Future.value(byUser[userId] ?? const []);
  }

  @override
  Future<FocusSession> saveCompleted(
    String userId,
    Map<String, dynamic> draft,
  ) =>
      throw UnimplementedError();
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

FocusSession _session(String id, String userId) {
  final completedAt = DateTime(2026, 10, 14, 12).toUtc();
  return FocusSession(
    id: id,
    sessionId: 'session-$id',
    userId: userId,
    taskId: 'task-$id',
    taskTitle: 'Task $id',
    taskDate: null,
    plannedDurationSeconds: 600,
    startedAt: DayweaveTimestamp(
      completedAt.subtract(const Duration(minutes: 10)),
    ),
    completedAt: DayweaveTimestamp(completedAt),
    pausedSeconds: 0,
    createdAt: DayweaveTimestamp(completedAt),
  );
}

ProviderContainer _container(
  _FakeAuthService auth,
  _FakeFocusRepository repository,
) =>
    ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        authStateProvider.overrideWith((ref) => auth.authStateChanges),
        focusRepositoryProvider.overrideWithValue(repository),
        focusHistoryProvider.overrideWith(
          () => FocusHistoryController(
            clock: () => DateTime(2026, 10, 14, 12),
          ),
        ),
      ],
    );

void main() {
  test('a pending previous-account request cannot overwrite the new account',
      () async {
    final events = StreamController<AuthState>.broadcast();
    final auth = _FakeAuthService(_user('user-a'), events);
    final repository = _FakeFocusRepository({
      'user-a': [_session('a', 'user-a')],
      'user-b': [_session('b', 'user-b')],
    });
    final pendingA = Completer<List<FocusSession>>();
    repository.pending = pendingA;
    final container = _container(auth, repository);
    addTearDown(() async {
      await events.close();
      container.dispose();
    });

    final controller = container.read(focusHistoryProvider.notifier);
    final loadA = controller.load();
    auth.user = _user('user-b');
    events.add(AuthState(AuthChangeEvent.signedIn, null));
    await container.pump();
    repository.pending = null;
    await controller.load();
    expect(controller.state.sessions.single.id, 'b');

    pendingA.complete([_session('a', 'user-a')]);
    await loadA;
    expect(controller.state.sessions.single.id, 'b');
  });

  testWidgets('mounted Focus History reloads for an account switch',
      (tester) async {
    final events = StreamController<AuthState>.broadcast();
    final auth = _FakeAuthService(_user('user-a'), events);
    final repository = _FakeFocusRepository({
      'user-a': [_session('a', 'user-a')],
      'user-b': [_session('b', 'user-b')],
    });
    addTearDown(events.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          authStateProvider.overrideWith((ref) => auth.authStateChanges),
          focusRepositoryProvider.overrideWithValue(repository),
          focusHistoryProvider.overrideWith(
            () => FocusHistoryController(
              clock: () => DateTime(2026, 10, 14, 12),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: FocusHistoryScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Task a'), findsOneWidget);

    auth.user = _user('user-b');
    events.add(AuthState(AuthChangeEvent.signedIn, null));
    await tester.pumpAndSettle();

    expect(find.text('Task a'), findsNothing);
    expect(find.text('Task b'), findsOneWidget);
  });
}
