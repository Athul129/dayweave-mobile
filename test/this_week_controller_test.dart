import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dayweave_mobile/core/date_time/dayweave_date_time.dart';
import 'package:dayweave_mobile/features/auth/application/current_user_provider.dart';
import 'package:dayweave_mobile/features/focus/application/focus_session_controller.dart';
import 'package:dayweave_mobile/features/week/application/this_week_controller.dart';
import 'package:dayweave_mobile/features/week/application/this_week_state.dart';
import 'package:dayweave_mobile/features/today/application/today_state.dart';
import 'package:dayweave_mobile/models/task.dart';
import 'package:dayweave_mobile/repositories/task_repository.dart';
import 'package:dayweave_mobile/services/providers.dart';

Task _task(String id, String date, {bool done = false, int minutes = 30}) =>
    Task(
      id: id,
      userId: 'user-1',
      title: id,
      note: 'Note',
      time: '09:00',
      minutes: minutes,
      energy: TaskEnergy.deep,
      done: done,
      section: TaskSection.morning,
      date: date,
    );

class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository(this.tasks);
  List<Task> tasks;
  Object? error;
  String? fetchedUserId;
  String? mutatedUserId;
  Map<String, dynamic>? lastDraft;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  Object? mutationError;
  Completer<void>? updateGate;
  final Map<String, Completer<List<Task>>> fetchWaiters = {};

  @override
  Future<List<Task>> fetchForUser(String userId) async {
    fetchedUserId = userId;
    final waiter = fetchWaiters[userId];
    if (waiter != null) return waiter.future;
    if (error != null) throw error!;
    return tasks;
  }

  @override
  Future<Task> create(String userId, Map<String, dynamic> draft) async {
    createCalls++;
    mutatedUserId = userId;
    lastDraft = draft;
    if (mutationError != null) throw mutationError!;
    final created = _task('created', draft['date'] as String,
        minutes: draft['minutes'] as int);
    tasks = [...tasks, created];
    return created;
  }

  @override
  Future<Task> update(
      String userId, String id, Map<String, dynamic> changes) async {
    updateCalls++;
    mutatedUserId = userId;
    lastDraft = changes;
    final gate = updateGate;
    if (gate != null) await gate.future;
    if (mutationError != null) throw mutationError!;
    final existing = tasks.firstWhere((task) => task.id == id);
    final updated = Task(
      id: existing.id,
      userId: existing.userId,
      title: changes['title'] as String? ?? existing.title,
      note: changes['note'] as String? ?? existing.note,
      time: changes['time'] as String? ?? existing.time,
      minutes: changes['minutes'] as int? ?? existing.minutes,
      energy: existing.energy,
      done: changes['done'] as bool? ?? existing.done,
      section: existing.section,
      date: changes['date'] as String? ?? existing.date,
    );
    tasks = tasks.map((task) => task.id == id ? updated : task).toList();
    return updated;
  }

  @override
  Future<void> delete(String userId, String id) async {
    deleteCalls++;
    mutatedUserId = userId;
    if (mutationError != null) throw mutationError!;
    tasks = tasks.where((task) => task.id != id).toList();
  }
}

ThisWeekState _state(LocalDate date, List<Task> tasks) => ThisWeekState(
      currentDate: date,
      weekOffset: 0,
      selectedDate: date,
      tasks: tasks,
    );

ProviderContainer _container(_FakeTaskRepository repository) =>
    ProviderContainer(overrides: [
      taskRepositoryProvider.overrideWithValue(repository),
      currentUserIdProvider.overrideWith((ref) => ref.watch(_testUser)),
    ]);

final _testUser = StateProvider<String?>((ref) => 'user-1');

void main() {
  test('Monday calculation works for every weekday', () {
    for (var weekday = 1; weekday <= 7; weekday++) {
      final date = LocalDate(2026, 10, 5).addDays(weekday - 1);
      expect(mondayFor(date), LocalDate(2026, 10, 5));
    }
  });

  test('week dates are seven consecutive Monday through Sunday dates', () {
    final state = _state(LocalDate(2026, 10, 7), const []);
    expect(state.weekDates.map((date) => date.iso), [
      '2026-10-05',
      '2026-10-06',
      '2026-10-07',
      '2026-10-08',
      '2026-10-09',
      '2026-10-10',
      '2026-10-11',
    ]);
  });

  test('week dates cross month and year boundaries', () {
    final state = _state(LocalDate(2027, 1, 1), const []);
    expect(state.weekDates.first.iso, '2026-12-28');
    expect(state.weekDates.last.iso, '2027-01-03');
  });

  test('filters displayed week and selected day and calculates summaries', () {
    final state = _state(LocalDate(2026, 10, 7), [
      _task('done', '2026-10-05', done: true, minutes: 45),
      _task('active', '2026-10-07', minutes: 30),
      _task('outside', '2026-10-12', minutes: 90),
    ]);
    expect(state.weekTasks.map((task) => task.id), ['done', 'active']);
    expect(state.selectedDayTasks.map((task) => task.id), ['active']);
    expect(state.completedCount, 1);
    expect(state.totalCount, 2);
    expect(state.completionPercentage, 50);
    expect(state.plannedMinutes, 75);
  });

  test('zero-task summary is safe', () {
    final state = _state(LocalDate(2026, 10, 7), const []);
    expect(state.completionPercentage, 0);
    expect(state.plannedMinutes, 0);
  });

  test('controller loads tasks for the authenticated user', () async {
    final repository = _FakeTaskRepository([_task('one', '2026-10-07')]);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    expect(repository.fetchedUserId, 'user-1');
    expect(container.read(thisWeekProvider).tasks.single.id, 'one');
    expect(container.read(thisWeekProvider).isLoading, isFalse);
  });

  test('moves a task to another date and preserves week selection', () async {
    final current = LocalDate.today();
    final target = current.addDays(1);
    final task = _task('move-task', current.iso);
    final earlier = _task('earlier', target.iso);
    final repository = _FakeTaskRepository([task, earlier]);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    final before = container.read(thisWeekProvider);

    await controller.moveTaskToDate(task.id, target);

    final state = container.read(thisWeekProvider);
    expect(repository.mutatedUserId, 'user-1');
    expect(repository.lastDraft, {'date': target.iso});
    expect(
        state.tasks.map((item) => item.id).toSet(), {'earlier', 'move-task'});
    expect(state.tasks.map((item) => item.date), [target.iso, target.iso]);
    expect(state.weekOffset, before.weekOffset);
    expect(state.selectedDate, before.selectedDate);
  });

  test('moving to the same date is a no-op', () async {
    final date = LocalDate.today();
    final task = _task('same-date', date.iso);
    final repository = _FakeTaskRepository([task]);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    await controller.moveTaskToDate(task.id, date);
    expect(repository.updateCalls, 0);
    expect(container.read(thisWeekProvider).tasks.single.date, date.iso);
  });

  test('completed and past tasks cannot be moved', () async {
    final today = LocalDate.today();
    final completed = _task('completed-move', today.iso, done: true);
    final past = _task('past-move', today.addDays(-1).iso);
    final repository = _FakeTaskRepository([completed, past]);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    await expectLater(controller.moveTaskToDate(completed.id, today.addDays(1)),
        throwsStateError);
    await expectLater(
        controller.moveTaskToDate(past.id, today), throwsStateError);
    expect(repository.updateCalls, 0);
  });

  test('Focus-protected task cannot be moved', () async {
    final task = _task('focus-move', LocalDate.today().iso);
    final repository = _FakeTaskRepository([task]);
    final container = _container(repository);
    addTearDown(container.dispose);
    final focus = container.read(focusSessionProvider.notifier);
    focus.start(task, now: DateTime(2026, 10, 31, 9));
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    await expectLater(
        controller.moveTaskToDate(task.id, LocalDate.today().addDays(1)),
        throwsA(isA<FocusProtectedTaskMutationException>()));
    focus.pause(now: DateTime(2026, 10, 31, 9, 0, 1));
    await expectLater(
        controller.moveTaskToDate(task.id, LocalDate.today().addDays(1)),
        throwsA(isA<FocusProtectedTaskMutationException>()));
    expect(repository.updateCalls, 0);
  });

  test('failed or duplicate moves preserve local state', () async {
    final task = _task('duplicate-move', LocalDate.today().iso);
    final repository = _FakeTaskRepository([task])
      ..updateGate = Completer<void>();
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    final first =
        controller.moveTaskToDate(task.id, LocalDate.today().addDays(1));
    await expectLater(
        controller.moveTaskToDate(task.id, LocalDate.today().addDays(2)),
        throwsStateError);
    repository.updateGate!.complete();
    await first;
    expect(container.read(thisWeekProvider).tasks.single.date,
        LocalDate.today().addDays(1).iso);

    repository.mutationError = StateError('offline');
    await expectLater(
        controller.moveTaskToDate(task.id, LocalDate.today().addDays(2)),
        throwsStateError);
    expect(container.read(thisWeekProvider).tasks.single.date,
        LocalDate.today().addDays(1).iso);
  });

  test('account change prevents a pending move from updating state', () async {
    final task = _task('account-move', LocalDate.today().iso);
    final repository = _FakeTaskRepository([task])
      ..updateGate = Completer<void>()
      ..fetchWaiters['user-2'] = Completer<List<Task>>();
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    final move =
        controller.moveTaskToDate(task.id, LocalDate.today().addDays(1));
    container.read(_testUser.notifier).state = 'user-2';
    repository.updateGate!.complete();
    await expectLater(move, throwsStateError);
    repository.fetchWaiters['user-2']!.complete(const []);
    await Future<void>.delayed(Duration.zero);
    expect(repository.mutatedUserId, 'user-1');
    expect(container.read(thisWeekProvider).tasks, isEmpty);
  });

  test('controller navigation keeps selected date inside the displayed week',
      () {
    final repository = _FakeTaskRepository(const []);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    controller.nextWeek();
    final next = container.read(thisWeekProvider);
    expect(next.weekOffset, 1);
    expect(next.weekDates, contains(next.selectedDate));
    controller.previousWeek();
    expect(container.read(thisWeekProvider).weekOffset, 0);
    controller.today();
    expect(container.read(thisWeekProvider).selectedDate,
        container.read(thisWeekProvider).currentDate);
  });

  test('selectDate ignores dates outside the displayed week', () {
    final repository = _FakeTaskRepository(const []);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    final original = container.read(thisWeekProvider).selectedDate;
    controller.selectDate(original.addDays(10));
    expect(container.read(thisWeekProvider).selectedDate, original);
  });

  test('load exposes an error and retry can recover', () async {
    final repository = _FakeTaskRepository(const [])
      ..error = StateError('offline');
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    expect(container.read(thisWeekProvider).error, isA<StateError>());
    repository.error = null;
    repository.tasks = [_task('recovered', LocalDate.today().iso)];
    await controller.load();
    expect(container.read(thisWeekProvider).error, isNull);
    expect(container.read(thisWeekProvider).tasks.single.id, 'recovered');
  });

  test('creates a task for the selected date and authenticated user', () async {
    final repository = _FakeTaskRepository(const []);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    final selected = LocalDate.today().addDays(2);
    await controller.createTask(TodayTaskDraft(
      title: 'Plan',
      note: 'Note',
      time: '09:00',
      minutes: 30,
      energy: TaskEnergy.deep,
      section: TaskSection.morning,
      date: selected,
    ));
    expect(repository.mutatedUserId, 'user-1');
    expect(repository.lastDraft?['date'], selected.iso);
    expect(container.read(thisWeekProvider).tasks.single.date, selected.iso);
  });

  test('updates a task and replaces it in local state', () async {
    final task = _task('one', LocalDate.today().iso);
    final repository = _FakeTaskRepository([task]);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    final updated = await controller.updateTask(
        task.id,
        TodayTaskDraft(
          title: 'Renamed',
          note: task.note,
          time: task.time,
          minutes: task.minutes,
          energy: task.energy,
          section: task.section,
          date: LocalDate.today(),
        ));
    expect(updated.title, 'Renamed');
    expect(container.read(thisWeekProvider).tasks.single.title, 'Renamed');
    expect(repository.updateCalls, 1);
  });

  test('failed create and update leave local state unchanged', () async {
    final task = _task('one', LocalDate.today().iso);
    final repository = _FakeTaskRepository([task])
      ..mutationError = StateError('offline');
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    final draft = TodayTaskDraft(
      title: 'New',
      note: 'Note',
      time: '09:00',
      minutes: 30,
      energy: TaskEnergy.deep,
      section: TaskSection.morning,
      date: LocalDate.today(),
    );
    await expectLater(controller.createTask(draft), throwsStateError);
    await expectLater(controller.updateTask(task.id, draft), throwsStateError);
    expect(
        container.read(thisWeekProvider).tasks.map((item) => item.id), ['one']);
  });

  test('running and paused Focus tasks cannot be edited', () async {
    final task = _task('one', LocalDate.today().iso);
    final repository = _FakeTaskRepository([task]);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    final focus = container.read(focusSessionProvider.notifier);
    final draft = TodayTaskDraft(
      title: 'Edited',
      note: task.note,
      time: task.time,
      minutes: task.minutes,
      energy: task.energy,
      section: task.section,
      date: LocalDate.today(),
    );

    focus.start(task, now: DateTime(2026, 10, 31, 9));
    await expectLater(controller.updateTask(task.id, draft),
        throwsA(isA<FocusProtectedTaskMutationException>()));
    focus.pause(now: DateTime(2026, 10, 31, 9, 0, 1));
    await expectLater(controller.updateTask(task.id, draft),
        throwsA(isA<FocusProtectedTaskMutationException>()));

    expect(repository.updateCalls, 0);
    expect(container.read(thisWeekProvider).tasks.single.title, task.title);
  });

  test('completed and past task dates remain locked', () async {
    final completed = _task('done', LocalDate.today().iso, done: true);
    final past = _task('past', LocalDate.today().addDays(-1).iso);
    final repository = _FakeTaskRepository([completed, past]);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    TodayTaskDraft draft(Task task) => TodayTaskDraft(
        title: task.title,
        note: task.note,
        time: task.time,
        minutes: task.minutes,
        energy: task.energy,
        section: task.section,
        date: LocalDate.today().addDays(1));
    await expectLater(controller.updateTask(completed.id, draft(completed)),
        throwsArgumentError);
    await expectLater(
        controller.updateTask(past.id, draft(past)), throwsArgumentError);
    expect(repository.updateCalls, 0);
  });

  test('duplicate update submissions are rejected', () async {
    final task = _task('one', LocalDate.today().iso);
    final repository = _FakeTaskRepository([task]);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    final draft = TodayTaskDraft(
        title: task.title,
        note: task.note,
        time: task.time,
        minutes: task.minutes,
        energy: task.energy,
        section: task.section,
        date: LocalDate.today());
    final first = controller.updateTask(task.id, draft);
    await expectLater(controller.updateTask(task.id, draft), throwsStateError);
    await first;
    expect(repository.updateCalls, 1);
  });

  test('completes and uncompletes a task with the authenticated user',
      () async {
    final task = _task('one', LocalDate.today().iso);
    final repository = _FakeTaskRepository([task]);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();

    await controller.completeTask(task.id);
    expect(repository.mutatedUserId, 'user-1');
    expect(repository.lastDraft?['done'], isTrue);
    expect(container.read(thisWeekProvider).tasks.single.done, isTrue);
    expect(container.read(thisWeekProvider).completedCount, 1);
    expect(container.read(thisWeekProvider).completionPercentage, 100);

    await controller.uncompleteTask(task.id);
    expect(repository.lastDraft?['done'], isFalse);
    expect(container.read(thisWeekProvider).tasks.single.done, isFalse);
    expect(container.read(thisWeekProvider).completedCount, 0);
    expect(container.read(thisWeekProvider).completionPercentage, 0);
  });

  test('failed completion and uncompletion preserve local state', () async {
    final task = _task('one', LocalDate.today().iso);
    final repository = _FakeTaskRepository([task])
      ..mutationError = StateError('offline');
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    await expectLater(controller.completeTask(task.id), throwsStateError);
    expect(container.read(thisWeekProvider).tasks.single.done, isFalse);
    repository.mutationError = null;
    await controller.completeTask(task.id);
    repository.mutationError = StateError('offline');
    await expectLater(controller.uncompleteTask(task.id), throwsStateError);
    expect(container.read(thisWeekProvider).tasks.single.done, isTrue);
  });

  test('running or paused Focus tasks cannot be changed', () async {
    final task = _task('one', LocalDate.today().iso);
    final repository = _FakeTaskRepository([task]);
    final container = _container(repository);
    addTearDown(container.dispose);
    final focus = container.read(focusSessionProvider.notifier);
    focus.start(task, now: DateTime(2026, 10, 31, 9));
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    await expectLater(controller.completeTask(task.id),
        throwsA(isA<FocusProtectedTaskMutationException>()));
    focus.pause(now: DateTime(2026, 10, 31, 9, 0, 1));
    await expectLater(controller.completeTask(task.id),
        throwsA(isA<FocusProtectedTaskMutationException>()));
    await expectLater(controller.uncompleteTask(task.id),
        throwsA(isA<FocusProtectedTaskMutationException>()));
    expect(repository.updateCalls, 0);
  });

  test('non-Focus tasks remain mutable', () async {
    final task = _task('one', LocalDate.today().iso);
    final repository = _FakeTaskRepository([task]);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    await controller.completeTask(task.id);
    expect(repository.updateCalls, 1);
    expect(container.read(thisWeekProvider).tasks.single.done, isTrue);
  });

  test('deletes only the target task and updates weekly state', () async {
    final target = _task('target', LocalDate.today().iso, minutes: 45);
    final other = _task('other', LocalDate.today().iso, minutes: 30);
    final repository = _FakeTaskRepository([target, other]);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    final beforeDate = container.read(thisWeekProvider).selectedDate;
    await controller.deleteTask(target.id);
    final state = container.read(thisWeekProvider);
    expect(repository.mutatedUserId, 'user-1');
    expect(repository.deleteCalls, 1);
    expect(state.tasks.map((task) => task.id), ['other']);
    expect(state.selectedDayTasks.map((task) => task.id), ['other']);
    expect(state.plannedMinutes, 30);
    expect(state.selectedDate, beforeDate);
  });

  test('failed deletion preserves local state', () async {
    final target = _task('target', LocalDate.today().iso);
    final repository = _FakeTaskRepository([target])
      ..mutationError = StateError('offline');
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    await expectLater(controller.deleteTask(target.id), throwsStateError);
    expect(container.read(thisWeekProvider).tasks.single.id, target.id);
  });

  test('running and paused Focus task deletion is blocked before repository',
      () async {
    final target = _task('target', LocalDate.today().iso);
    final repository = _FakeTaskRepository([target]);
    final container = _container(repository);
    addTearDown(container.dispose);
    final focus = container.read(focusSessionProvider.notifier);
    focus.start(target, now: DateTime(2026, 10, 31, 9));
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    await expectLater(controller.deleteTask(target.id),
        throwsA(isA<FocusProtectedTaskMutationException>()));
    focus.pause(now: DateTime(2026, 10, 31, 9, 0, 1));
    await expectLater(controller.deleteTask(target.id),
        throwsA(isA<FocusProtectedTaskMutationException>()));
    expect(repository.deleteCalls, 0);
  });

  test('duplicate deletion submissions are rejected', () async {
    final target = _task('target', LocalDate.today().iso);
    final repository = _FakeTaskRepository([target]);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    final first = controller.deleteTask(target.id);
    await expectLater(controller.deleteTask(target.id), throwsStateError);
    await first;
    expect(repository.deleteCalls, 1);
  });

  test('account changes discard pending loads and load the new account',
      () async {
    final repository = _FakeTaskRepository(const [])
      ..fetchWaiters['user-1'] = Completer<List<Task>>()
      ..fetchWaiters['user-2'] = Completer<List<Task>>();
    final container = _container(repository);
    addTearDown(container.dispose);
    container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    container.read(_testUser.notifier).state = 'user-2';
    repository.fetchWaiters['user-1']!
        .complete([_task('old', LocalDate.today().iso)]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(thisWeekProvider).tasks, isEmpty);

    repository.fetchWaiters['user-2']!
        .complete([_task('new', LocalDate.today().iso)]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(thisWeekProvider).tasks.single.id, 'new');
    expect(repository.fetchedUserId, 'user-2');
  });

  test('signing out clears existing This Week tasks', () async {
    final repository =
        _FakeTaskRepository([_task('old', LocalDate.today().iso)]);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(thisWeekProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();
    expect(container.read(thisWeekProvider).tasks, isNotEmpty);

    container.read(_testUser.notifier).state = null;
    await Future<void>.delayed(Duration.zero);
    expect(container.read(thisWeekProvider).tasks, isEmpty);
    expect(container.read(thisWeekProvider).isLoading, isFalse);
  });
}
