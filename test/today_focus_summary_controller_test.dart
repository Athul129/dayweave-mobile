import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dayweave_mobile/core/date_time/dayweave_date_time.dart';
import 'package:dayweave_mobile/features/auth/application/current_user_provider.dart';
import 'package:dayweave_mobile/features/today/application/today_focus_summary_controller.dart';
import 'package:dayweave_mobile/models/domain_models.dart';
import 'package:dayweave_mobile/repositories/focus_repository.dart';
import 'package:dayweave_mobile/services/providers.dart';

class _FakeFocusRepository implements FocusRepository {
  _FakeFocusRepository(this.sessions);
  final List<FocusSession> sessions;
  Object? error;
  String? fetchedUserId;

  @override
  Future<List<FocusSession>> fetchForUser(String userId) async {
    fetchedUserId = userId;
    if (error != null) throw error!;
    return sessions;
  }

  @override
  Future<FocusSession> saveCompleted(
          String userId, Map<String, dynamic> draft) async =>
      throw UnimplementedError();
}

FocusSession _session(String id, DateTime completedAt, int plannedSeconds) =>
    FocusSession(
      id: id,
      sessionId: 'session-$id',
      userId: 'user-1',
      taskId: 'task-$id',
      taskTitle: 'Task $id',
      taskDate: LocalDate.today(),
      plannedDurationSeconds: plannedSeconds,
      startedAt: DayweaveTimestamp(
          completedAt.toUtc().subtract(const Duration(minutes: 30))),
      completedAt: DayweaveTimestamp(completedAt.toUtc()),
      pausedSeconds: 0,
      createdAt: DayweaveTimestamp(completedAt.toUtc()),
    );

ProviderContainer _container(_FakeFocusRepository repository,
        {String? userId = 'user-1'}) =>
    ProviderContainer(overrides: [
      focusRepositoryProvider.overrideWithValue(repository),
      currentUserIdProvider.overrideWithValue(userId),
    ]);

void main() {
  test('includes sessions whose completed timestamp is today locally',
      () async {
    final now = DateTime.now();
    final repository = _FakeFocusRepository([
      _session('today', now, 90),
      _session('yesterday', now.subtract(const Duration(days: 1)), 600),
    ]);
    final container = _container(repository);
    addTearDown(container.dispose);

    final controller = container.read(todayFocusSummaryProvider.notifier);
    await controller.load();

    expect(repository.fetchedUserId, 'user-1');
    expect(controller.state.sessionCount, 1);
    expect(controller.state.plannedMinutes, 2);
  });

  test('handles a UTC timestamp that converts to today locally', () async {
    final now = DateTime.now();
    final localMidnight = DateTime(now.year, now.month, now.day);
    final repository = _FakeFocusRepository([
      _session(
          'near-midnight', localMidnight.add(const Duration(minutes: 1)), 60),
    ]);
    final container = _container(repository);
    addTearDown(container.dispose);

    final controller = container.read(todayFocusSummaryProvider.notifier);
    await controller.load();

    expect(controller.state.sessionCount, 1);
  });

  test('counts today sessions and rounds planned minutes like Web', () async {
    final now = DateTime.now();
    final repository = _FakeFocusRepository([
      _session('one', now, 61),
      _session('two', now, 60),
      _session('three', now, 59),
    ]);
    final container = _container(repository);
    addTearDown(container.dispose);

    final controller = container.read(todayFocusSummaryProvider.notifier);
    await controller.load();

    expect(controller.state.sessionCount, 3);
    expect(controller.state.plannedMinutes, 3);
  });

  test('exposes empty, error, and missing-user states', () async {
    final emptyRepository = _FakeFocusRepository([]);
    final emptyContainer = _container(emptyRepository);
    addTearDown(emptyContainer.dispose);
    final emptyController =
        emptyContainer.read(todayFocusSummaryProvider.notifier);
    await emptyController.load();
    expect(emptyController.state.sessionCount, 0);
    expect(emptyController.state.error, isNull);

    final errorRepository = _FakeFocusRepository([])
      ..error = StateError('failed');
    final errorContainer = _container(errorRepository);
    addTearDown(errorContainer.dispose);
    final errorController =
        errorContainer.read(todayFocusSummaryProvider.notifier);
    await errorController.load();
    expect(errorController.state.error, isA<StateError>());
    expect(errorController.state.isLoading, isFalse);

    final missingContainer = _container(_FakeFocusRepository([]), userId: null);
    addTearDown(missingContainer.dispose);
    final missingController =
        missingContainer.read(todayFocusSummaryProvider.notifier);
    await missingController.load();
    expect(missingController.state.error, isA<StateError>());
  });
}
