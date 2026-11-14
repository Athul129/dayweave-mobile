import 'dart:async';

import 'package:dayweave_mobile/core/date_time/dayweave_date_time.dart';
import 'package:dayweave_mobile/features/auth/application/current_user_provider.dart';
import 'package:dayweave_mobile/features/focus_history/application/focus_history_controller.dart';
import 'package:dayweave_mobile/features/focus_history/presentation/focus_history_screen.dart';
import 'package:dayweave_mobile/models/domain_models.dart';
import 'package:dayweave_mobile/repositories/focus_repository.dart';
import 'package:dayweave_mobile/services/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFocusRepository implements FocusRepository {
  _FakeFocusRepository(this.sessions);

  List<FocusSession> sessions;
  Object? error;
  Completer<List<FocusSession>>? response;
  String? requestedUserId;
  int fetchCalls = 0;

  @override
  Future<List<FocusSession>> fetchForUser(String userId) {
    fetchCalls++;
    requestedUserId = userId;
    if (response case final pending?) return pending.future;
    if (error case final failure?) return Future.error(failure);
    return Future.value(sessions);
  }

  @override
  Future<FocusSession> saveCompleted(
    String userId,
    Map<String, dynamic> draft,
  ) =>
      throw UnimplementedError();
}

FocusSession _session(
  String id,
  DateTime completedAt, {
  int plannedSeconds = 0,
  int pausedSeconds = 0,
}) =>
    FocusSession(
      id: id,
      sessionId: 'session-$id',
      userId: 'user-7',
      taskId: 'task-$id',
      taskTitle: 'Task $id',
      taskDate: null,
      plannedDurationSeconds: plannedSeconds,
      startedAt: DayweaveTimestamp(
        completedAt.toUtc().subtract(const Duration(minutes: 30)),
      ),
      completedAt: DayweaveTimestamp(completedAt.toUtc()),
      pausedSeconds: pausedSeconds,
      createdAt: DayweaveTimestamp(completedAt.toUtc()),
    );

ProviderContainer _container(
  _FakeFocusRepository repository, {
  required DateTime now,
  String? userId = 'user-7',
}) =>
    ProviderContainer(
      overrides: [
        focusRepositoryProvider.overrideWithValue(repository),
        currentUserIdProvider.overrideWithValue(userId),
        focusHistoryProvider.overrideWith(
          () => FocusHistoryController(clock: () => now),
        ),
      ],
    );

void main() {
  final now = DateTime(2026, 10, 14, 12); // Wednesday, local time.
  final sessions = [
    _session('september', DateTime(2026, 9, 30, 23, 59), plannedSeconds: 300),
    _session(
      'month-start',
      DateTime(2026, 10, 1),
      plannedSeconds: 60,
      pausedSeconds: 3,
    ),
    _session(
      'monday',
      DateTime(2026, 10, 12, 8),
      plannedSeconds: 90,
      pausedSeconds: 60,
    ),
    _session(
      'sunday',
      DateTime(2026, 10, 18, 23, 59),
      plannedSeconds: 120,
      pausedSeconds: 30,
    ),
    // The following Monday is outside this week but still in this month.
    _session('next-monday', DateTime(2026, 10, 19), plannedSeconds: 600),
    _session('november', DateTime(2026, 11, 1), plannedSeconds: 900),
  ];

  test(
    'fetches history for the authenticated user and sorts newest first',
    () async {
      final repository = _FakeFocusRepository(sessions.reversed.toList());
      final container = _container(repository, now: now);
      addTearDown(container.dispose);

      await container.read(focusHistoryProvider.notifier).load();
      final state = container.read(focusHistoryProvider);

      expect(repository.requestedUserId, 'user-7');
      expect(state.sessions.map((session) => session.id), [
        'november',
        'next-monday',
        'sunday',
        'monday',
        'month-start',
        'september',
      ]);
    },
  );

  test(
    'All time, this week, and this month use local calendar boundaries',
    () async {
      final repository = _FakeFocusRepository(sessions);
      final container = _container(repository, now: now);
      addTearDown(container.dispose);
      final controller = container.read(focusHistoryProvider.notifier);
      await controller.load();

      expect(
        container.read(focusHistoryProvider).filteredSessions,
        hasLength(6),
      );

      controller.selectPeriod(FocusHistoryPeriod.thisWeek);
      expect(
        container
            .read(focusHistoryProvider)
            .filteredSessions
            .map((session) => session.id),
        ['sunday', 'monday'],
      );

      controller.selectPeriod(FocusHistoryPeriod.thisMonth);
      expect(
        container
            .read(focusHistoryProvider)
            .filteredSessions
            .map((session) => session.id),
        ['next-monday', 'sunday', 'monday', 'month-start'],
      );
    },
  );

  test(
    'groups by local completion date and calculates matching totals',
    () async {
      final repository = _FakeFocusRepository(sessions);
      final container = _container(repository, now: now);
      addTearDown(container.dispose);
      final controller = container.read(focusHistoryProvider.notifier);
      await controller.load();
      controller.selectPeriod(FocusHistoryPeriod.thisMonth);
      final state = container.read(focusHistoryProvider);

      expect(state.completedCount, 4);
      expect(state.plannedSeconds, 870);
      expect(formatFocusDuration(state.plannedSeconds), '14 min 30 sec');
      expect(state.pausedSeconds, 93);
      expect(state.dayGroups.map((group) => group.date.iso), [
        '2026-10-19',
        '2026-10-18',
        '2026-10-12',
        '2026-10-01',
      ]);
      expect(state.groupLabel(state.dayGroups[0].date), 'Oct 19, 2026');
      expect(state.groupLabel(state.dayGroups[1].date), 'Oct 18, 2026');
      expect(formatFocusDuration(0), '0 sec');
      expect(formatFocusDuration(60), '1 min');
      expect(formatFocusDuration(65), '1 min 5 sec');
    },
  );

  test(
    'empty result and missing user do not make an invalid request',
    () async {
      final emptyRepository = _FakeFocusRepository([]);
      final emptyContainer = _container(emptyRepository, now: now);
      addTearDown(emptyContainer.dispose);
      await emptyContainer.read(focusHistoryProvider.notifier).load();
      expect(
        emptyContainer.read(focusHistoryProvider).filteredSessions,
        isEmpty,
      );
      expect(emptyContainer.read(focusHistoryProvider).error, isNull);

      final noUserRepository = _FakeFocusRepository(sessions);
      final noUserContainer = _container(
        noUserRepository,
        now: now,
        userId: null,
      );
      addTearDown(noUserContainer.dispose);
      await noUserContainer.read(focusHistoryProvider.notifier).load();
      expect(noUserRepository.fetchCalls, 0);
      expect(noUserContainer.read(focusHistoryProvider).isLoading, isFalse);
      expect(
        noUserContainer.read(focusHistoryProvider).filteredSessions,
        isEmpty,
      );
    },
  );

  test('exposes loading and error state and can retry after failure', () async {
    final repository = _FakeFocusRepository([])
      ..response = Completer<List<FocusSession>>();
    final container = _container(repository, now: now);
    addTearDown(container.dispose);
    final controller = container.read(focusHistoryProvider.notifier);

    final loading = controller.load();
    expect(container.read(focusHistoryProvider).isLoading, isTrue);
    repository.response!.complete(sessions);
    repository.response = null;
    await loading;
    expect(container.read(focusHistoryProvider).sessions, hasLength(6));

    repository
      ..error = StateError('network unavailable')
      ..sessions = [];
    await controller.load();
    expect(container.read(focusHistoryProvider).error, isA<StateError>());
    expect(container.read(focusHistoryProvider).isLoading, isFalse);

    repository.error = null;
    repository.sessions = sessions;
    await controller.load();
    expect(repository.fetchCalls, 3);
    expect(container.read(focusHistoryProvider).error, isNull);
    expect(container.read(focusHistoryProvider).sessions, hasLength(6));
  });

  test('refresh preserves sessions while pending and replaces them on success',
      () async {
    final repository = _FakeFocusRepository([
      _session('old', DateTime(2026, 10, 14, 9)),
    ]);
    final container = _container(repository, now: now);
    addTearDown(container.dispose);
    final controller = container.read(focusHistoryProvider.notifier);
    await controller.load();

    repository.response = Completer<List<FocusSession>>();
    final refresh = controller.load();
    expect(container.read(focusHistoryProvider).isLoading, isFalse);
    expect(container.read(focusHistoryProvider).isRefreshing, isTrue);
    expect(
      container.read(focusHistoryProvider).sessions.single.id,
      'old',
    );

    repository.response!.complete([
      _session('new', DateTime(2026, 10, 14, 10)),
    ]);
    repository.response = null;
    await refresh;

    final state = container.read(focusHistoryProvider);
    expect(state.isRefreshing, isFalse);
    expect(state.error, isNull);
    expect(state.sessions.single.id, 'new');
  });

  test('failed refresh preserves sessions and retry can recover', () async {
    final repository = _FakeFocusRepository([
      _session('loaded', DateTime(2026, 10, 14, 9), plannedSeconds: 120),
    ]);
    final container = _container(repository, now: now);
    addTearDown(container.dispose);
    final controller = container.read(focusHistoryProvider.notifier);
    await controller.load();

    repository.response = Completer<List<FocusSession>>();
    final failedRefresh = controller.load();
    expect(container.read(focusHistoryProvider).isRefreshing, isTrue);
    repository.response!.completeError(StateError('offline'));
    repository.response = null;
    await failedRefresh;

    var state = container.read(focusHistoryProvider);
    expect(state.isLoading, isFalse);
    expect(state.isRefreshing, isFalse);
    expect(state.error, isA<StateError>());
    expect(state.sessions.single.id, 'loaded');
    expect(state.plannedSeconds, 120);

    repository.sessions = [
      _session('recovered', DateTime(2026, 10, 14, 10)),
    ];
    await controller.load();
    state = container.read(focusHistoryProvider);
    expect(state.error, isNull);
    expect(state.sessions.single.id, 'recovered');
  });

  testWidgets('screen Retry reloads history after an error', (tester) async {
    final repository = _FakeFocusRepository([])
      ..error = StateError('temporary error');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusRepositoryProvider.overrideWithValue(repository),
          currentUserIdProvider.overrideWithValue('user-7'),
          focusHistoryProvider.overrideWith(
            () => FocusHistoryController(clock: () => now),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: FocusHistoryScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);

    repository.error = null;
    repository.sessions = [_session('loaded', DateTime(2026, 10, 14, 9))];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repository.fetchCalls, 2);
    expect(find.text('Task loaded'), findsOneWidget);
  });

  testWidgets('refresh failure keeps visible history and offers retry',
      (tester) async {
    final repository = _FakeFocusRepository([
      _session('loaded', DateTime(2026, 10, 14, 9)),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusRepositoryProvider.overrideWithValue(repository),
          currentUserIdProvider.overrideWithValue('user-7'),
          focusHistoryProvider.overrideWith(
            () => FocusHistoryController(clock: () => now),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: FocusHistoryScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Task loaded'), findsOneWidget);

    repository.error = StateError('offline');
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();

    expect(find.text('Task loaded'), findsOneWidget);
    expect(find.text('Unable to refresh Focus History.'), findsOneWidget);

    repository
      ..error = null
      ..sessions = [_session('recovered', DateTime(2026, 10, 14, 10))];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Task loaded'), findsNothing);
    expect(find.text('Task recovered'), findsOneWidget);
    expect(find.text('Unable to refresh Focus History.'), findsNothing);
  });

  testWidgets('pull to refresh reloads history and updates its summary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeFocusRepository([]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusRepositoryProvider.overrideWithValue(repository),
          currentUserIdProvider.overrideWithValue('user-7'),
          focusHistoryProvider.overrideWith(
            () => FocusHistoryController(clock: () => now),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: FocusHistoryScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.fetchCalls, 1);
    expect(find.text('No focus sessions yet'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<FocusHistoryPeriod>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This month').last);
    await tester.pumpAndSettle();

    repository.response = Completer<List<FocusSession>>();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 400),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.fetchCalls, 2);
    expect(
      tester
          .widget<DropdownButton<FocusHistoryPeriod>>(
            find.byType(DropdownButton<FocusHistoryPeriod>),
          )
          .value,
      FocusHistoryPeriod.thisMonth,
    );
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    repository.response!.complete([
      _session('fresh-a', DateTime(2026, 10, 14, 10), plannedSeconds: 60),
      _session('fresh-b', DateTime(2026, 10, 14, 11), plannedSeconds: 120),
    ]);
    repository.response = null;
    await tester.pumpAndSettle();

    expect(repository.fetchCalls, 2);
    expect(find.text('Task fresh-a'), findsOneWidget);
    expect(find.text('Task fresh-b'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3 min'), findsOneWidget);
    expect(find.text('No focus sessions yet'), findsNothing);
  });

  test('period filters honor local calendar boundaries', () async {
    final localMonday = DateTime(2026, 10, 12);
    final localFirstOfMonth = DateTime(2026, 10, 1);
    final sessionsAtBoundaries = [
      _session(
          'before-monday', localMonday.subtract(const Duration(minutes: 1))),
      _session('monday-midnight', localMonday),
      _session('sunday', DateTime(2026, 10, 18, 23, 59, 59)),
      _session('next-monday-midnight', DateTime(2026, 10, 19)),
      _session('last-day-of-month', DateTime(2026, 10, 31, 23, 59, 59)),
      _session('next-month-first-day', DateTime(2026, 11, 1)),
      // This is a UTC instant that resolves to September 30 locally, even
      // though its UTC calendar date is October 1.
      _session(
        'utc-previous-local-day',
        localFirstOfMonth.toUtc().subtract(const Duration(minutes: 1)),
      ),
    ];
    final repository = _FakeFocusRepository(sessionsAtBoundaries);
    final container = _container(repository, now: now);
    addTearDown(container.dispose);
    final controller = container.read(focusHistoryProvider.notifier);
    await controller.load();

    expect(
      container.read(focusHistoryProvider).filteredSessions.map((s) => s.id),
      [
        'next-month-first-day',
        'last-day-of-month',
        'next-monday-midnight',
        'sunday',
        'monday-midnight',
        'before-monday',
        'utc-previous-local-day',
      ],
    );

    controller.selectPeriod(FocusHistoryPeriod.thisWeek);
    expect(
      container
          .read(focusHistoryProvider)
          .filteredSessions
          .map((session) => session.id),
      ['sunday', 'monday-midnight'],
    );

    controller.selectPeriod(FocusHistoryPeriod.thisMonth);
    expect(
      container
          .read(focusHistoryProvider)
          .filteredSessions
          .map((session) => session.id),
      [
        'last-day-of-month',
        'next-monday-midnight',
        'sunday',
        'monday-midnight',
        'before-monday',
      ],
    );

    controller.selectPeriod(FocusHistoryPeriod.allTime);
    expect(
      container.read(focusHistoryProvider).filteredSessions.map((s) => s.id),
      [
        'next-month-first-day',
        'last-day-of-month',
        'next-monday-midnight',
        'sunday',
        'monday-midnight',
        'before-monday',
        'utc-previous-local-day',
      ],
    );
  });
}
