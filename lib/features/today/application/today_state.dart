import '../../../core/date_time/dayweave_date_time.dart';
import '../../../models/task.dart';

enum TodayStatusFilter { all, active, completed }
enum TodayEnergyFilter { all, deep, light, social }
enum TodaySectionFilter { all, morning, midday, afternoon }

class TodayState {
  const TodayState({
    required this.date,
    required this.tasks,
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.statusFilter = TodayStatusFilter.all,
    this.energyFilter = TodayEnergyFilter.all,
    this.sectionFilter = TodaySectionFilter.all,
    this.activeTaskId,
  });

  factory TodayState.initial() => TodayState(date: LocalDate.today(), tasks: const [], isLoading: true);

  final LocalDate date;
  final List<Task> tasks;
  final bool isLoading;
  final Object? error;
  final String searchQuery;
  final TodayStatusFilter statusFilter;
  final TodayEnergyFilter energyFilter;
  final TodaySectionFilter sectionFilter;
  final String? activeTaskId;

  TodayState copyWith({
    LocalDate? date,
    List<Task>? tasks,
    bool? isLoading,
    Object? error = _unset,
    String? searchQuery,
    TodayStatusFilter? statusFilter,
    TodayEnergyFilter? energyFilter,
    TodaySectionFilter? sectionFilter,
    Object? activeTaskId = _unset,
  }) => TodayState(
        date: date ?? this.date,
        tasks: tasks ?? this.tasks,
        isLoading: isLoading ?? this.isLoading,
        error: identical(error, _unset) ? this.error : error,
        searchQuery: searchQuery ?? this.searchQuery,
        statusFilter: statusFilter ?? this.statusFilter,
        energyFilter: energyFilter ?? this.energyFilter,
        sectionFilter: sectionFilter ?? this.sectionFilter,
        activeTaskId: identical(activeTaskId, _unset) ? this.activeTaskId : activeTaskId as String?,
      );
}

const _unset = Object();

class TodayTaskDraft {
  const TodayTaskDraft({required this.title, required this.note, required this.time, required this.minutes, required this.energy, required this.section, required this.date});
  final String title;
  final String note;
  final String time;
  final int minutes;
  final TaskEnergy energy;
  final TaskSection section;
  final LocalDate date;

  Map<String, dynamic> toDatabase() => {
        'title': title.trim(),
        'note': note.trim().isEmpty ? 'A small, clear next step.' : note.trim(),
        'time': time,
        'minutes': minutes,
        'energy': energy.name[0].toUpperCase() + energy.name.substring(1),
        'section': section.name[0].toUpperCase() + section.name.substring(1),
        'date': date.iso,
      };
}

Map<String, String> validateTodayTaskDraft(TodayTaskDraft draft, LocalDate today) {
  final errors = <String, String>{};
  if (draft.title.trim().isEmpty) errors['title'] = 'Give this task a short title.';
  final time = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(draft.time);
  if (time == null || int.parse(time.group(1)!) > 23 || int.parse(time.group(2)!) > 59) {
    errors['time'] = 'Use a time between 00:00 and 23:59.';
  }
  if (draft.minutes < 1 || draft.minutes > 1440) errors['minutes'] = 'Choose a duration from 1 to 1,440 minutes.';
  if (draft.date.iso.compareTo(today.iso) < 0) errors['date'] = 'Tasks can’t be scheduled for a past date.';
  return errors;
}

class TodaySelectors {
  const TodaySelectors(this.state);
  final TodayState state;

  List<Task> get todayTasks => state.tasks.where((task) => task.date == state.date.iso).toList(growable: false);
  List<Task> get filteredTasks {
    final query = state.searchQuery.trim().toLowerCase();
    return todayTasks.where((task) {
      final textMatches = query.isEmpty || '${task.title} ${task.note}'.toLowerCase().contains(query);
      final statusMatches = state.statusFilter == TodayStatusFilter.all ||
          state.statusFilter == TodayStatusFilter.completed && task.done ||
          state.statusFilter == TodayStatusFilter.active && !task.done;
      final energyMatches = state.energyFilter == TodayEnergyFilter.all || task.energy.name == state.energyFilter.name;
      final sectionMatches = state.sectionFilter == TodaySectionFilter.all || task.section.name == state.sectionFilter.name;
      return textMatches && statusMatches && energyMatches && sectionMatches;
    }).toList(growable: false);
  }

  List<Task> tasksFor(TaskSection section) => filteredTasks.where((task) => task.section == section).toList(growable: false);
  int get completedCount => todayTasks.where((task) => task.done).length;
  int get totalCount => todayTasks.length;
  int get progress => totalCount == 0 ? 0 : ((completedCount / totalCount) * 100).round();
  int get remainingMinutes => todayTasks.where((task) => !task.done).fold(0, (sum, task) => sum + task.minutes);
  int get totalPlannedMinutes => todayTasks.fold(0, (sum, task) => sum + task.minutes);

  Task? get upNext {
    final tasks = todayTasks;
    final selected = state.activeTaskId == null ? null : tasks.where((task) => task.id == state.activeTaskId).firstOrNull;
    return selected ?? tasks.where((task) => !task.done).firstOrNull ?? tasks.firstOrNull;
  }
}
