import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_time/dayweave_date_time.dart';
import '../../../core/theme/dayweave_theme.dart';
import '../../../features/focus/application/focus_session_controller.dart';
import '../../../models/task.dart';
import '../application/this_week_controller.dart';
import '../application/this_week_state.dart';
import '../../today/presentation/widgets/today_task_form.dart';

class ThisWeekScreen extends ConsumerWidget {
  const ThisWeekScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(thisWeekProvider);
    final focus = ref.watch(focusSessionProvider);
    final controller = ref.read(thisWeekProvider.notifier);
    final protectedFocusTaskId =
        focus.isRunning || focus.isPaused ? focus.task?.id : null;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: controller.load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              DayweaveSpacing.lg, 8, DayweaveSpacing.lg, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _WeekIntro(),
              const SizedBox(height: 20),
              _WeekSummary(state: state),
              const SizedBox(height: 18),
              _WeekNavigation(state: state, controller: controller),
              const SizedBox(height: 12),
              _DaySelector(state: state, controller: controller),
              const SizedBox(height: 20),
              if (state.isLoading && state.tasks.isEmpty)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator()))
              else if (state.error != null)
                _ErrorState(onRetry: controller.load)
              else
                _SelectedDay(
                    state: state,
                    controller: controller,
                    protectedFocusTaskId: protectedFocusTaskId),
              const SizedBox(height: 24),
              const _BreathingNote(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekIntro extends StatelessWidget {
  const _WeekIntro();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        decoration: const BoxDecoration(
            color: DayweaveColors.bluePaper, borderRadius: DayweaveRadii.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WEEKLY FIELD NOTES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: DayweaveColors.inkSoft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8)),
          const SizedBox(height: 12),
          Text('Make a week\nthat can breathe.',
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(fontSize: 34, height: .98)),
          const SizedBox(height: 12),
          Text(
              'See the shape of what’s ahead without filling every inch of it.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: DayweaveColors.inkSoft, height: 1.45)),
        ]),
      );
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary({required this.state});
  final ThisWeekState state;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: DayweaveColors.card, borderRadius: DayweaveRadii.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WEEK IN VIEW',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: DayweaveColors.inkSoft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4)),
          const SizedBox(height: 6),
          Text('${state.completionPercentage}% clear',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text('${state.completedCount} of ${state.totalCount} tasks complete',
              style: Theme.of(context).textTheme.bodyLarge),
          Text('${state.plannedMinutes}m planned across the week',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: DayweaveColors.inkSoft)),
        ]),
      );
}

class _WeekNavigation extends StatelessWidget {
  const _WeekNavigation({required this.state, required this.controller});
  final ThisWeekState state;
  final ThisWeekController controller;
  @override
  Widget build(BuildContext context) {
    final first = state.weekDates.first;
    final last = state.weekDates.last;
    return Row(children: [
      IconButton(
          onPressed: controller.previousWeek,
          tooltip: 'Previous week',
          icon: const Icon(Icons.chevron_left)),
      Expanded(
          child: Text(
              '${_month(first.month)} ${first.day} — ${last.day}, ${last.year}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall)),
      IconButton(
          onPressed: controller.nextWeek,
          tooltip: 'Next week',
          icon: const Icon(Icons.chevron_right)),
      if (state.weekOffset != 0)
        TextButton(onPressed: controller.today, child: const Text('Today')),
    ]);
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.state, required this.controller});
  final ThisWeekState state;
  final ThisWeekController controller;
  @override
  Widget build(BuildContext context) => Row(children: [
        for (final date in state.weekDates)
          Expanded(
              child: _DayChip(
                  date: date,
                  selected: date == state.selectedDate,
                  current: date == state.currentDate,
                  onTap: () => controller.selectDate(date))),
      ]);
}

class _DayChip extends StatelessWidget {
  const _DayChip(
      {required this.date,
      required this.selected,
      required this.current,
      required this.onTap});
  final LocalDate date;
  final bool selected;
  final bool current;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label:
            '${_weekday(date.asLocalDateTime.weekday)}, ${date.month}/${date.day}${current ? ', today' : ''}',
        child: InkWell(
          onTap: onTap,
          borderRadius: DayweaveRadii.md,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
                color: selected
                    ? DayweaveColors.marigold
                    : DayweaveColors.sage.withValues(alpha: .35),
                borderRadius: DayweaveRadii.md),
            child: Column(children: [
              Text(_weekday(date.asLocalDateTime.weekday).substring(0, 3),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(fontSize: 9)),
              const SizedBox(height: 3),
              Text('${date.day}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

class _SelectedDay extends StatefulWidget {
  const _SelectedDay(
      {required this.state,
      required this.controller,
      required this.protectedFocusTaskId});
  final ThisWeekState state;
  final ThisWeekController controller;
  final String? protectedFocusTaskId;

  @override
  State<_SelectedDay> createState() => _SelectedDayState();
}

class _SelectedDayState extends State<_SelectedDay> {
  final Set<String> _pendingCompletionIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final tasks = state.selectedDayTasks;
    final done = tasks.where((task) => task.done).length;
    final minutes = tasks.fold(0, (sum, task) => sum + task.minutes);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(
                '${_weekday(state.selectedDate.asLocalDateTime.weekday)}, ${_month(state.selectedDate.month)} ${state.selectedDate.day}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontSize: 24))),
        OutlinedButton.icon(
            onPressed: () => _openCreate(context),
            icon: const Icon(Icons.add, size: 17),
            label: const Text('Add task')),
      ]),
      const SizedBox(height: 6),
      Text(
          '${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'} · $done done · ${minutes}m planned',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: DayweaveColors.inkSoft)),
      const SizedBox(height: 16),
      if (tasks.isEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('No tasks yet. A little space is a good thing.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: DayweaveColors.inkSoft)),
          const SizedBox(height: 10),
          TextButton.icon(
              onPressed: () => _openCreate(context),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Plan a task')),
        ])
      else
        ...tasks.map((task) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _WeekTaskRow(
                task: task,
                onEdit: () => _openEdit(context, task,
                    isFocusProtected: task.id == widget.protectedFocusTaskId),
                onToggleComplete: () => _toggleComplete(context, task),
                onMove: () => _openMove(context, task)))),
    ]);
  }

  Future<void> _openCreate(BuildContext context) async {
    await showTodayTaskFormSheet(
      context: context,
      today: LocalDate.today(),
      initial: defaultTodayTaskDraft(widget.state.selectedDate),
      onSave: widget.controller.createTask,
    );
  }

  Future<void> _openEdit(BuildContext context, Task task,
      {bool isFocusProtected = false}) async {
    if (isFocusProtected) {
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
            content: Text(
                "This task can't be changed while its Focus session is active.")));
      return;
    }
    await showTodayTaskFormSheet(
      context: context,
      today: LocalDate.today(),
      editing: task,
      onSave: (draft) => widget.controller.updateTask(task.id, draft),
      onDelete: () => widget.controller.deleteTask(task.id),
    );
  }

  Future<void> _toggleComplete(BuildContext context, Task task) async {
    if (!_pendingCompletionIds.add(task.id)) return;
    try {
      await (task.done
          ? widget.controller.uncompleteTask(task.id)
          : widget.controller.completeTask(task.id));
    } catch (error) {
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(
          content: Text(error is FocusProtectedTaskMutationException
              ? "This task can't be changed while its Focus session is active."
              : 'Task could not be updated. Please try again.')));
    } finally {
      _pendingCompletionIds.remove(task.id);
    }
  }

  Future<void> _openMove(BuildContext context, Task task) async {
    var moving = false;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final today = LocalDate.today();
          final reason = task.done
              ? 'Completed tasks cannot be moved.'
              : task.date.compareTo(today.iso) < 0
                  ? 'Past tasks cannot be moved.'
                  : null;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Move task',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(task.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (reason != null) ...[
                    const SizedBox(height: 8),
                    Text(reason,
                        style: const TextStyle(color: DayweaveColors.inkSoft)),
                  ],
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.state.weekDates.length,
                      itemBuilder: (context, index) {
                        final date = widget.state.weekDates[index];
                        final isCurrent = date.iso == task.date;
                        final isPast = date.iso.compareTo(today.iso) < 0;
                        final enabled = !moving && reason == null && !isPast;
                        return ListTile(
                          enabled: enabled || isCurrent,
                          selected: isCurrent,
                          leading: Icon(isCurrent
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked),
                          title: Text(
                              '${_weekday(date.asLocalDateTime.weekday)}, ${_month(date.month)} ${date.day}'),
                          subtitle: isCurrent
                              ? const Text('Current day')
                              : isPast
                                  ? const Text('Past date')
                                  : null,
                          onTap: enabled
                              ? () async {
                                  setSheetState(() => moving = true);
                                  try {
                                    await widget.controller
                                        .moveTaskToDate(task.id, date);
                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                        ..clearSnackBars()
                                        ..showSnackBar(const SnackBar(
                                            content: Text(
                                                'Task moved successfully.')));
                                    }
                                  } catch (error) {
                                    if (!sheetContext.mounted) return;
                                    setSheetState(() => moving = false);
                                    ScaffoldMessenger.of(sheetContext)
                                      ..clearSnackBars()
                                      ..showSnackBar(SnackBar(
                                          content: Text(error
                                                  is FocusProtectedTaskMutationException
                                              ? "This task can't be moved while its Focus session is active."
                                              : 'Task could not be moved. Please try again.')));
                                  }
                                }
                              : null,
                        );
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: moving
                            ? null
                            : () => Navigator.of(sheetContext).pop(),
                        child: const Text('Cancel')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WeekTaskRow extends StatelessWidget {
  const _WeekTaskRow(
      {required this.task,
      required this.onEdit,
      required this.onToggleComplete,
      required this.onMove});
  final Task task;
  final VoidCallback onEdit;
  final VoidCallback onToggleComplete;
  final VoidCallback onMove;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: DayweaveColors.card,
            border: Border.all(color: DayweaveColors.line),
            borderRadius: DayweaveRadii.md),
        child: Row(children: [
          IconButton(
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              onPressed: onToggleComplete,
              tooltip: task.done
                  ? 'Mark ${task.title} active'
                  : 'Mark ${task.title} complete',
              icon: Icon(task.done ? Icons.check_circle : Icons.circle_outlined,
                  color: task.done
                      ? Colors.green.shade600
                      : DayweaveColors.inkSoft)),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text(
                    '${task.time} · ${task.energy.name[0].toUpperCase()}${task.energy.name.substring(1)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: DayweaveColors.inkSoft)),
              ])),
          IconButton(
              onPressed: onEdit,
              tooltip: 'Edit ${task.title}',
              icon: const Icon(Icons.edit_outlined, size: 19)),
          IconButton(
              onPressed: onMove,
              tooltip: 'Move ${task.title} to another day',
              icon: const Icon(Icons.drive_file_move_outlined, size: 19)),
          Text('${task.minutes}m',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: DayweaveColors.inkSoft)),
        ]),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(children: [
        const Icon(Icons.error_outline, color: DayweaveColors.coral),
        const SizedBox(height: 8),
        const Text('Your week could not be loaded.'),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ]);
}

class _BreathingNote extends StatelessWidget {
  const _BreathingNote();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: DayweaveColors.bluePaper.withValues(alpha: .55),
            borderRadius: DayweaveRadii.lg),
        child: Text('Leave a little room between\nthe landmarks.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                color: DayweaveColors.inkSoft)),
      );
}

String _weekday(int weekday) => const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ][weekday - 1];
String _month(int month) => const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ][month - 1];
