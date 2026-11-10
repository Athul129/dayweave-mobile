import '../../../core/date_time/dayweave_date_time.dart';
import '../../../models/task.dart';

LocalDate mondayFor(LocalDate date) => date.addDays(
      -(date.asLocalDateTime.weekday - DateTime.monday),
    );

class ThisWeekState {
  const ThisWeekState({
    required this.currentDate,
    required this.weekOffset,
    required this.selectedDate,
    required this.tasks,
    this.isLoading = false,
    this.error,
  });

  factory ThisWeekState.initial({LocalDate? currentDate}) {
    final today = currentDate ?? LocalDate.today();
    return ThisWeekState(
      currentDate: today,
      weekOffset: 0,
      selectedDate: today,
      tasks: const [],
      isLoading: true,
    );
  }

  final LocalDate currentDate;
  final int weekOffset;
  final LocalDate selectedDate;
  final List<Task> tasks;
  final bool isLoading;
  final Object? error;

  LocalDate get weekStart =>
      mondayFor(currentDate).addDays(weekOffset * DateTime.daysPerWeek);

  List<LocalDate> get weekDates => List<LocalDate>.generate(
        DateTime.daysPerWeek,
        (index) => weekStart.addDays(index),
        growable: false,
      );

  List<Task> get weekTasks {
    final dates = weekDates.map((date) => date.iso).toSet();
    return tasks
        .where((task) => dates.contains(task.date))
        .toList(growable: false);
  }

  List<Task> get selectedDayTasks => tasks
      .where((task) => task.date == selectedDate.iso)
      .toList(growable: false);

  int get completedCount => weekTasks.where((task) => task.done).length;
  int get totalCount => weekTasks.length;
  int get completionPercentage =>
      totalCount == 0 ? 0 : ((completedCount / totalCount) * 100).round();
  int get plannedMinutes =>
      weekTasks.fold(0, (total, task) => total + task.minutes);

  ThisWeekState copyWith({
    LocalDate? currentDate,
    int? weekOffset,
    LocalDate? selectedDate,
    List<Task>? tasks,
    bool? isLoading,
    Object? error = _unset,
  }) =>
      ThisWeekState(
        currentDate: currentDate ?? this.currentDate,
        weekOffset: weekOffset ?? this.weekOffset,
        selectedDate: selectedDate ?? this.selectedDate,
        tasks: tasks ?? this.tasks,
        isLoading: isLoading ?? this.isLoading,
        error: identical(error, _unset) ? this.error : error,
      );
}

const _unset = Object();
