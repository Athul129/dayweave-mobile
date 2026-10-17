import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dayweave_mobile/core/date_time/dayweave_date_time.dart';
import 'package:dayweave_mobile/features/auth/application/current_user_provider.dart';
import 'package:dayweave_mobile/features/today/application/today_controller.dart';
import 'package:dayweave_mobile/features/today/application/today_state.dart';
import 'package:dayweave_mobile/models/task.dart';
import 'package:dayweave_mobile/repositories/task_repository.dart';
import 'package:dayweave_mobile/services/providers.dart';

Task controllerTask(String id, String time, {String? date}) => Task(
      id: id,
      userId: 'user-1',
      title: id,
      note: 'Note',
      time: time,
      minutes: 30,
      energy: TaskEnergy.light,
      done: false,
      section: TaskSection.morning,
      date: date ?? LocalDate.today().iso,
    );

TodayTaskDraft draftFor(Task task,
        {String? time, String? date, TaskSection? section}) =>
    TodayTaskDraft(
      title: task.title,
      note: task.note,
      time: time ?? task.time,
      minutes: task.minutes,
      energy: task.energy,
      section: section ?? task.section,
      date: LocalDate.parse(date ?? task.date),
    );

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository(this.tasks);

  List<Task> tasks;
  String? updatedId;
  Map<String, dynamic>? changes;
  String? createdUserId;
  Map<String, dynamic>? createdDraft;
  Object? updateError;

  @override
  Future<List<Task>> fetchForUser(String userId) async => tasks;

  @override
  Future<Task> create(String userId, Map<String, dynamic> draft) async {
    createdUserId = userId;
    createdDraft = draft;
    final created = Task(
      id: 'created',
      userId: userId,
      title: draft['title'] as String,
      note: draft['note'] as String,
      time: draft['time'] as String,
      minutes: draft['minutes'] as int,
      energy: taskEnergyFromDatabase(draft['energy'] as String),
      done: false,
      section: taskSectionFromDatabase(draft['section'] as String),
      date: draft['date'] as String,
    );
    tasks = [...tasks, created];
    return created;
  }

  @override
  Future<Task> update(
      String userId, String id, Map<String, dynamic> updateChanges) async {
    if (updateError != null) throw updateError!;
    updatedId = id;
    changes = updateChanges;
    final current = tasks.firstWhere((task) => task.id == id);
    final updated = Task(
      id: current.id,
      userId: current.userId,
      title: current.title,
      note: current.note,
      time: updateChanges['time'] as String? ?? current.time,
      minutes: current.minutes,
      energy: current.energy,
      done: updateChanges['done'] as bool? ?? current.done,
      section: updateChanges['section'] == null
          ? current.section
          : taskSectionFromDatabase(updateChanges['section'] as String),
      date: updateChanges['date'] as String? ?? current.date,
    );
    tasks = tasks.map((task) => task.id == id ? updated : task).toList();
    return updated;
  }

  @override
  Future<void> delete(String userId, String id) => throw UnimplementedError();
}

ProviderContainer controllerContainer(FakeTaskRepository repository) {
  return ProviderContainer(
    overrides: [
      taskRepositoryProvider.overrideWithValue(repository),
      currentUserIdProvider.overrideWithValue('user-1'),
    ],
  );
}

void main() {
  final first = controllerTask('first', '09:00');
  final second = controllerTask('second', '12:00');
  final third = controllerTask('third', '18:00');

  test('Later sends the task ID and sorts the updated task', () async {
    final repository = FakeTaskRepository([first, second, third]);
    final container = controllerContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(todayControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    final updated = await controller.later('first');

    expect(repository.updatedId, 'first');
    expect(repository.changes, {'time': '16:30', 'section': 'Afternoon'});
    expect(updated.time, '16:30');
    expect(updated.section, TaskSection.afternoon);
    expect(controller.state.tasks.map((task) => task.id),
        ['second', 'first', 'third']);
  });

  test('Later failure leaves local tasks unchanged and propagates', () async {
    final repository = FakeTaskRepository([first, second]);
    repository.updateError = StateError('update failed');
    final container = controllerContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(todayControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    final before = controller.state.tasks;

    await expectLater(controller.later('first'), throwsStateError);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.tasks, same(before));
  });

  test('normal update replaces and sorts the task', () async {
    final repository = FakeTaskRepository([first, second, third]);
    final container = controllerContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(todayControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    await controller.updateTask('third', draftFor(third, time: '08:30'));

    expect(controller.state.tasks.map((task) => task.id),
        ['third', 'first', 'second']);
  });

  test('creating a future task sends its selected date and section', () async {
    final repository = FakeTaskRepository([]);
    final container = controllerContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(todayControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    final futureDate = LocalDate.today().addDays(1);
    await controller.createTask(TodayTaskDraft(
      title: 'Future task',
      note: 'Note',
      time: '09:30',
      minutes: 30,
      energy: TaskEnergy.light,
      section: TaskSection.midday,
      date: futureDate,
    ));

    expect(repository.createdDraft, containsPair('date', futureDate.iso));
    expect(repository.createdDraft, containsPair('section', 'Midday'));
    expect(repository.createdUserId, 'user-1');
    expect(controller.state.tasks,
        contains(isA<Task>().having((task) => task.id, 'id', 'created')));
    final created = controller.state.tasks.single;
    expect(created.date, futureDate.iso);
    expect(created.section, TaskSection.midday);
  });

  test('updating a task date replaces it and removes it from Today', () async {
    final current = controllerTask('current', '09:00');
    final unrelated = controllerTask('unrelated', '10:00');
    final repository = FakeTaskRepository([current, unrelated]);
    final container = controllerContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(todayControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    final futureDate = LocalDate.today().addDays(1);
    final updated = await controller.updateTask(
      current.id,
      draftFor(current, date: futureDate.iso),
    );

    expect(repository.changes, containsPair('date', futureDate.iso));
    expect(updated, isNotNull);
    expect(updated!.date, futureDate.iso);
    expect(controller.state.tasks.map((task) => task.id),
        containsAll(<String>['current', 'unrelated']));
    expect(
        controller.state.tasks.firstWhere((task) => task.id == current.id).date,
        futureDate.iso);
    expect(
        controller.state.tasks
            .firstWhere((task) => task.id == unrelated.id)
            .date,
        unrelated.date);
    expect(controller.selectors.todayTasks.map((task) => task.id),
        contains('unrelated'));
    expect(controller.selectors.todayTasks.map((task) => task.id),
        isNot(contains('current')));
  });

  test('failed date update leaves local state unchanged', () async {
    final current = controllerTask('current', '09:00');
    final repository = FakeTaskRepository([current]);
    repository.updateError = StateError('update failed');
    final container = controllerContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(todayControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    final before = controller.state.tasks;

    await expectLater(
      controller.updateTask(
        current.id,
        draftFor(current, date: LocalDate.today().addDays(1).iso),
      ),
      throwsStateError,
    );

    expect(controller.state.tasks, same(before));
  });

  test('completed tasks cannot be moved to another date', () async {
    final current = controllerTask('completed', '09:00');
    final completed = Task(
      id: current.id,
      userId: current.userId,
      title: current.title,
      note: current.note,
      time: current.time,
      minutes: current.minutes,
      energy: current.energy,
      done: true,
      section: current.section,
      date: current.date,
    );
    final repository = FakeTaskRepository([completed]);
    final container = controllerContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(todayControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      controller.updateTask(
        completed.id,
        draftFor(completed, date: LocalDate.today().addDays(1).iso),
      ),
      throwsArgumentError,
    );
    expect(repository.updatedId, isNull);
  });

  test('past tasks cannot be moved to another date', () async {
    final past = controllerTask(
      'past',
      '09:00',
      date: LocalDate.today().addDays(-1).iso,
    );
    final repository = FakeTaskRepository([past]);
    final container = controllerContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(todayControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      controller.updateTask(
        past.id,
        draftFor(past, date: LocalDate.today().iso),
      ),
      throwsArgumentError,
    );
    expect(repository.updatedId, isNull);
  });

  test('section update persists and moves the task between selectors',
      () async {
    final current = controllerTask('sectioned', '09:00');
    final unrelated = controllerTask('unrelated', '10:00');
    final repository = FakeTaskRepository([current, unrelated]);
    final container = controllerContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(todayControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    await controller.updateTask(
      current.id,
      draftFor(current, section: TaskSection.afternoon),
    );

    expect(repository.changes, containsPair('section', 'Afternoon'));
    expect(controller.selectors.tasksFor(TaskSection.morning),
        contains(isA<Task>().having((task) => task.id, 'id', unrelated.id)));
    expect(controller.selectors.tasksFor(TaskSection.afternoon),
        contains(isA<Task>().having((task) => task.id, 'id', current.id)));
    final unchanged =
        controller.state.tasks.firstWhere((task) => task.id == unrelated.id);
    expect(unchanged.date, unrelated.date);
    expect(unchanged.time, unrelated.time);
    expect(unchanged.section, unrelated.section);
  });

  test('failed section update leaves local state unchanged', () async {
    final current = controllerTask('sectioned', '09:00');
    final repository = FakeTaskRepository([current]);
    repository.updateError = StateError('update failed');
    final container = controllerContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(todayControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    final before = controller.state.tasks;

    await expectLater(
      controller.updateTask(
        current.id,
        draftFor(current, section: TaskSection.afternoon),
      ),
      throwsStateError,
    );
    expect(controller.state.tasks, same(before));
  });
}
