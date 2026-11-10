import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_time/dayweave_date_time.dart';
import '../../../features/auth/application/current_user_provider.dart';
import '../../../features/focus/application/focus_session_controller.dart';
import '../../../models/task.dart';
import '../../../repositories/task_repository.dart';
import '../../../services/providers.dart';
import '../../today/application/today_state.dart';
import 'this_week_state.dart';

class FocusProtectedTaskMutationException implements Exception {
  const FocusProtectedTaskMutationException();

  @override
  String toString() =>
      'This task cannot be changed while its Focus session is active.';
}

final thisWeekProvider =
    NotifierProvider<ThisWeekController, ThisWeekState>(ThisWeekController.new);

class ThisWeekController extends Notifier<ThisWeekState> {
  late final TaskRepository _repository;
  String? _activeUserId;
  int _loadVersion = 0;
  bool _disposed = false;
  Future<void> _mutationTail = Future<void>.value();
  final Set<String> _mutatingTaskIds = <String>{};
  bool _creating = false;

  @override
  ThisWeekState build() {
    _repository = ref.watch(taskRepositoryProvider);
    _disposed = false;
    _activeUserId = ref.read(currentUserIdProvider);
    ref.onDispose(() => _disposed = true);
    ref.listen<String?>(currentUserIdProvider, (_, nextUserId) {
      if (nextUserId == _activeUserId || _disposed) return;
      _activeUserId = nextUserId;
      _loadVersion++;
      state = state.copyWith(
        tasks: const [],
        isLoading: nextUserId != null,
        error: null,
      );
      if (nextUserId != null) {
        load();
      }
    });
    final initial = ThisWeekState.initial();
    Future<void>.microtask(load);
    return initial;
  }

  Future<void> load() async {
    final version = ++_loadVersion;
    final userId = ref.read(currentUserIdProvider);
    _activeUserId = userId;
    if (userId == null) {
      if (_disposed) return;
      state = state.copyWith(tasks: const [], isLoading: false, error: null);
      return;
    }
    if (_disposed) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tasks = await _repository.fetchForUser(userId);
      if (!_canApplyLoad(version, userId)) return;
      state = state.copyWith(tasks: tasks, isLoading: false, error: null);
    } catch (error) {
      if (!_canApplyLoad(version, userId)) return;
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  void previousWeek() => _moveWeek(state.weekOffset - 1);
  void nextWeek() => _moveWeek(state.weekOffset + 1);

  void today() => state = state.copyWith(
        weekOffset: 0,
        selectedDate: state.currentDate,
      );

  void selectDate(LocalDate date) {
    if (state.weekDates.contains(date)) {
      state = state.copyWith(selectedDate: date);
    }
  }

  void _moveWeek(int offset) {
    state = state.copyWith(
      weekOffset: offset,
      selectedDate:
          mondayFor(state.currentDate).addDays(offset * DateTime.daysPerWeek),
    );
  }

  Future<Task> createTask(TodayTaskDraft draft) async {
    final today = LocalDate.today();
    final errors = validateTodayTaskDraft(draft, today);
    if (errors.isNotEmpty) throw ArgumentError.value(errors, 'draft');
    if (_creating) throw StateError('A task is already being saved.');
    _creating = true;
    final userId = _requireUser();
    try {
      return await _enqueueMutation(() async {
        final created = await _repository.create(userId, draft.toDatabase());
        if (!_isCurrentUser(userId)) {
          throw StateError('Authentication changed while saving the task.');
        }
        state = state.copyWith(
          tasks: [...state.tasks, created],
          error: null,
        );
        return created;
      });
    } finally {
      _creating = false;
    }
  }

  Future<Task> updateTask(String id, TodayTaskDraft draft) async {
    final current = state.tasks.where((task) => task.id == id).firstOrNull;
    if (current == null) throw ArgumentError.value(id, 'id');
    final focus = ref.read(focusSessionProvider);
    if (focus.task?.id == id && (focus.isRunning || focus.isPaused)) {
      throw const FocusProtectedTaskMutationException();
    }
    final today = LocalDate.today();
    final errors = validateTodayTaskDraft(draft, today);
    if (current.done && draft.date.iso != current.date) {
      errors['date'] = 'Completed tasks cannot be moved.';
    }
    if (current.date.compareTo(today.iso) < 0 &&
        draft.date.iso != current.date) {
      errors['date'] = 'Existing past task dates remain locked.';
    }
    if (errors.isNotEmpty) throw ArgumentError.value(errors, 'draft');
    if (!_mutatingTaskIds.add(id)) {
      throw StateError('This task is already being saved.');
    }
    final userId = _requireUser();
    try {
      return await _enqueueMutation(() async {
        final updated =
            await _repository.update(userId, id, draft.toDatabase());
        if (!_isCurrentUser(userId)) {
          throw StateError('Authentication changed while saving the task.');
        }
        state = state.copyWith(
          tasks: state.tasks
              .map((task) => task.id == id ? updated : task)
              .toList(growable: false),
          error: null,
        );
        return updated;
      });
    } finally {
      _mutatingTaskIds.remove(id);
    }
  }

  Future<bool> setCompleted(String id, bool completed) async {
    final current = state.tasks.where((task) => task.id == id).firstOrNull;
    if (current == null) throw ArgumentError.value(id, 'id');
    final focus = ref.read(focusSessionProvider);
    if (focus.task?.id == id && (focus.isRunning || focus.isPaused)) {
      throw const FocusProtectedTaskMutationException();
    }
    if (!_mutatingTaskIds.add(id)) {
      throw StateError('This task is already being updated.');
    }
    final userId = _requireUser();
    try {
      final updated = await _enqueueMutation(
          () => _repository.update(userId, id, {'done': completed}));
      if (!_isCurrentUser(userId)) {
        throw StateError('Authentication changed while updating the task.');
      }
      state = state.copyWith(
        tasks: state.tasks
            .map((task) => task.id == id ? updated : task)
            .toList(growable: false),
        error: null,
      );
      return updated.done == completed;
    } finally {
      _mutatingTaskIds.remove(id);
    }
  }

  Future<bool> completeTask(String id) => setCompleted(id, true);

  Future<bool> uncompleteTask(String id) => setCompleted(id, false);

  Future<void> moveTaskToDate(String taskId, LocalDate targetDate) async {
    final current = state.tasks.where((task) => task.id == taskId).firstOrNull;
    if (current == null) throw ArgumentError.value(taskId, 'taskId');
    if (current.done) {
      throw StateError('Completed tasks cannot be moved.');
    }
    final today = LocalDate.today();
    if (targetDate.iso.compareTo(today.iso) < 0 ||
        current.date.compareTo(today.iso) < 0 &&
            targetDate.iso != current.date) {
      throw StateError('Tasks cannot be moved to a past date.');
    }
    final focus = ref.read(focusSessionProvider);
    if (focus.task?.id == taskId && (focus.isRunning || focus.isPaused)) {
      throw const FocusProtectedTaskMutationException();
    }
    if (targetDate.iso == current.date) return;
    if (!_mutatingTaskIds.add(taskId)) {
      throw StateError('This task is already being updated.');
    }
    final userId = _requireUser();
    try {
      final updated = await _enqueueMutation(
          () => _repository.update(userId, taskId, {'date': targetDate.iso}));
      if (!_isCurrentUser(userId)) {
        throw StateError('Authentication changed while moving the task.');
      }
      final tasks = state.tasks
          .map((task) => task.id == taskId ? updated : task)
          .toList()
        ..sort(_compareTasks);
      state = state.copyWith(tasks: tasks, error: null);
    } finally {
      _mutatingTaskIds.remove(taskId);
    }
  }

  Future<void> deleteTask(String id) async {
    final current = state.tasks.where((task) => task.id == id).firstOrNull;
    if (current == null) throw ArgumentError.value(id, 'id');
    final focus = ref.read(focusSessionProvider);
    if (focus.task?.id == id && (focus.isRunning || focus.isPaused)) {
      throw const FocusProtectedTaskMutationException();
    }
    if (!_mutatingTaskIds.add(id)) {
      throw StateError('This task is already being updated.');
    }
    final userId = _requireUser();
    try {
      await _enqueueMutation(() => _repository.delete(userId, id));
      if (!_isCurrentUser(userId)) {
        throw StateError('Authentication changed while deleting the task.');
      }
      state = state.copyWith(
        tasks:
            state.tasks.where((task) => task.id != id).toList(growable: false),
        error: null,
      );
    } finally {
      _mutatingTaskIds.remove(id);
    }
  }

  Future<T> _enqueueMutation<T>(Future<T> Function() operation) {
    final result = _mutationTail.then((_) => operation());
    _mutationTail = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  String _requireUser() =>
      ref.read(currentUserIdProvider) ??
      (throw StateError('Authentication is required.'));

  bool _isCurrentUser(String userId) =>
      !_disposed && ref.read(currentUserIdProvider) == userId;

  bool _canApplyLoad(int version, String userId) =>
      !_disposed &&
      version == _loadVersion &&
      _activeUserId == userId &&
      ref.read(currentUserIdProvider) == userId;

  int _compareTasks(Task left, Task right) {
    final date = left.date.compareTo(right.date);
    return date == 0 ? left.time.compareTo(right.time) : date;
  }
}
