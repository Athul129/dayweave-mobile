import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_time/dayweave_date_time.dart';
import '../../../features/auth/application/current_user_provider.dart';
import '../../../models/task.dart';
import '../../../repositories/task_repository.dart';
import '../../../services/providers.dart';
import 'task_mutation_queue.dart';
import 'today_state.dart';

final todayControllerProvider =
    NotifierProvider<TodayController, TodayState>(TodayController.new);

class TodayController extends Notifier<TodayState> {
  late final TaskRepository _repository;
  final TaskMutationQueue _mutations = TaskMutationQueue();

  @override
  TodayState build() {
    _repository = ref.watch(taskRepositoryProvider);
    Future<void>.microtask(load);
    return TodayState.initial();
  }

  TodaySelectors get selectors => TodaySelectors(state);

  Future<void> load() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(tasks: const [], isLoading: false, error: null);
      return;
    }
    final date = state.date;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tasks = await _repository.fetchForUser(userId);
      state = state.copyWith(
          date: date, tasks: tasks, isLoading: false, error: null);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  void refreshDate() {
    final date = LocalDate.today();
    if (date != state.date) {
      state = state.copyWith(date: date, activeTaskId: null);
    }
  }

  void setSearchQuery(String value) =>
      state = state.copyWith(searchQuery: value);
  void setStatusFilter(TodayStatusFilter value) =>
      state = state.copyWith(statusFilter: value);
  void setEnergyFilter(TodayEnergyFilter value) =>
      state = state.copyWith(energyFilter: value);
  void setSectionFilter(TodaySectionFilter value) =>
      state = state.copyWith(sectionFilter: value);
  void selectTask(String? id) => state = state.copyWith(activeTaskId: id);

  Future<Task?> createTask(TodayTaskDraft draft) async {
    final errors = validateTodayTaskDraft(draft, state.date);
    if (errors.isNotEmpty) throw ArgumentError.value(errors, 'draft');
    final userId = _requireUser();
    return _mutations.add(() async {
      final created = await _repository.create(userId, draft.toDatabase());
      final tasks = [...state.tasks, created]..sort(_compareTasks);
      state =
          state.copyWith(tasks: tasks, activeTaskId: created.id, error: null);
      return created;
    });
  }

  Future<Task?> updateTask(String id, TodayTaskDraft draft) async {
    final current = state.tasks.where((task) => task.id == id).firstOrNull;
    if (current == null) throw ArgumentError.value(id, 'id');
    final errors = validateTodayTaskDraft(draft, state.date);
    if (current.done && draft.date.iso != current.date) {
      errors['date'] = 'Completed tasks cannot be moved.';
    }
    if (current.date.compareTo(state.date.iso) < 0 &&
        draft.date.iso != current.date) {
      errors['date'] = 'Existing past task dates remain locked.';
    }
    if (errors.isNotEmpty) throw ArgumentError.value(errors, 'draft');
    final updated = await _mutations
        .add(() => _repository.update(_requireUser(), id, draft.toDatabase()));
    state = state.copyWith(
        tasks: state.tasks
            .map((task) => task.id == id ? updated : task)
            .toList(growable: false),
        error: null);
    return updated;
  }

  Future<bool> setCompleted(String id, bool completed) async {
    final updated = await _mutations
        .add(() => _repository.update(_requireUser(), id, {'done': completed}));
    state = state.copyWith(
        tasks: state.tasks
            .map((task) => task.id == id ? updated : task)
            .toList(growable: false),
        error: null);
    return updated.done == completed;
  }

  Future<bool> completeTask(String id) => setCompleted(id, true);
  Future<bool> uncompleteTask(String id) => setCompleted(id, false);

  Future<void> deleteTask(String id) async {
    await _mutations.add(() => _repository.delete(_requireUser(), id));
    state = state.copyWith(
        tasks:
            state.tasks.where((task) => task.id != id).toList(growable: false),
        activeTaskId: state.activeTaskId == id ? null : state.activeTaskId,
        error: null);
  }

  Future<Task> later(String id) async {
    final updated = await _mutations.add(() => _repository
        .update(_requireUser(), id, {'time': '16:30', 'section': 'Afternoon'}));
    state = state.copyWith(
        tasks: state.tasks
            .map((task) => task.id == id ? updated : task)
            .toList(growable: false),
        error: null);
    return updated;
  }

  String _requireUser() =>
      ref.read(currentUserIdProvider) ??
      (throw StateError('Authentication is required.'));

  int _compareTasks(Task left, Task right) {
    final date = left.date.compareTo(right.date);
    return date == 0 ? left.time.compareTo(right.time) : date;
  }
}
