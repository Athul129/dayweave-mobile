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

TodayTaskDraft draftFor(Task task, {String? time}) => TodayTaskDraft(
      title: task.title,
      note: task.note,
      time: time ?? task.time,
      minutes: task.minutes,
      energy: task.energy,
      section: task.section,
      date: LocalDate.parse(task.date),
    );

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository(this.tasks);

  List<Task> tasks;
  String? updatedId;
  Map<String, dynamic>? changes;
  Object? updateError;

  @override
  Future<List<Task>> fetchForUser(String userId) async => tasks;

  @override
  Future<Task> create(String userId, Map<String, dynamic> draft) =>
      throw UnimplementedError();

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
      date: current.date,
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
}
