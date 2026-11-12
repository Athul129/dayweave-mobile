import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dayweave_mobile/core/date_time/dayweave_date_time.dart';
import 'package:dayweave_mobile/features/auth/application/current_user_provider.dart';
import 'package:dayweave_mobile/features/focus/application/focus_session_controller.dart';
import 'package:dayweave_mobile/features/preferences/application/preferences_controller.dart';
import 'package:dayweave_mobile/features/preferences/application/preferences_storage.dart';
import 'package:dayweave_mobile/features/week/presentation/this_week_screen.dart';
import 'package:dayweave_mobile/models/task.dart';
import 'package:dayweave_mobile/repositories/task_repository.dart';
import 'package:dayweave_mobile/services/providers.dart';

Task _task(String id, String date, {bool done = false}) => Task(
      id: id,
      userId: 'user-1',
      title: id,
      note: 'A note',
      time: '09:00',
      minutes: 30,
      energy: TaskEnergy.deep,
      done: done,
      section: TaskSection.morning,
      date: date,
    );

class _FakeRepository implements TaskRepository {
  _FakeRepository(this.tasks);
  List<Task> tasks;
  Object? fetchError;
  Object? mutationError;
  int fetchCalls = 0;
  int updateCalls = 0;
  String? updatedTaskId;
  int deleteCalls = 0;

  @override
  Future<List<Task>> fetchForUser(String userId) async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    return tasks;
  }

  @override
  Future<Task> create(String userId, Map<String, dynamic> draft) async {
    if (mutationError != null) throw mutationError!;
    final created = _task('created', draft['date'] as String);
    tasks = [...tasks, created];
    return created;
  }

  @override
  Future<Task> update(
      String userId, String id, Map<String, dynamic> changes) async {
    updateCalls++;
    updatedTaskId = id;
    if (mutationError != null) throw mutationError!;
    final current = tasks.firstWhere((task) => task.id == id);
    final updated = Task(
      id: current.id,
      userId: current.userId,
      title: current.title,
      note: current.note,
      time: current.time,
      minutes: current.minutes,
      energy: current.energy,
      done: changes['done'] as bool? ?? current.done,
      section: current.section,
      date: changes['date'] as String? ?? current.date,
    );
    tasks = tasks.map((task) => task.id == id ? updated : task).toList();
    return updated;
  }

  @override
  Future<void> delete(String userId, String id) async {
    deleteCalls++;
    if (mutationError != null) throw mutationError!;
    tasks = tasks.where((task) => task.id != id).toList();
  }
}

class _FakePreferencesStorage implements PreferencesStorage {
  int? value;

  @override
  Future<int?> readDefaultTaskMinutes() async => value;

  @override
  Future<void> writeDefaultTaskMinutes(int value) async {
    this.value = value;
  }
}

Widget _app(_FakeRepository repository) => ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        currentUserIdProvider.overrideWithValue('user-1'),
        preferencesStorageProvider.overrideWithValue(_FakePreferencesStorage()),
      ],
      child: const MaterialApp(home: Scaffold(body: ThisWeekScreen())),
    );

Widget _appWithFocus(_FakeRepository repository, Task task,
        {bool paused = false, bool completed = false}) =>
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repository),
        currentUserIdProvider.overrideWithValue('user-1'),
        preferencesStorageProvider.overrideWithValue(_FakePreferencesStorage()),
      ],
      child: _FocusHarness(task: task, paused: paused, completed: completed),
    );

class _FocusHarness extends ConsumerStatefulWidget {
  const _FocusHarness(
      {required this.task, required this.paused, required this.completed});
  final Task task;
  final bool paused;
  final bool completed;

  @override
  ConsumerState<_FocusHarness> createState() => _FocusHarnessState();
}

class _FocusHarnessState extends ConsumerState<_FocusHarness> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      final focus = ref.read(focusSessionProvider.notifier);
      focus.start(widget.task, now: DateTime(2026, 10, 31, 9));
      if (widget.paused) {
        focus.pause(now: DateTime(2026, 10, 31, 9, 0, 1));
      } else if (widget.completed) {
        focus.complete();
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: Scaffold(body: ThisWeekScreen()));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -360));
  await tester.pump();
}

const _weekdays = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _months = <String>[
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
  'December',
];

String _dateLabel(LocalDate date) =>
    '${_weekdays[date.asLocalDateTime.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';

Finder _sheetScrollable(Finder sheet) =>
    find.descendant(of: sheet, matching: find.byType(Scrollable));

List<LocalDate> _currentWeekDates() {
  final todayDate = LocalDate.today();
  final monday =
      todayDate.addDays(-(todayDate.asLocalDateTime.weekday - DateTime.monday));
  return List<LocalDate>.generate(7, monday.addDays);
}

Future<_FakeRepository> _openMoveSheet(
    WidgetTester tester, String todayDate) async {
  final repository = _FakeRepository([_task('today', todayDate)]);
  await tester.pumpWidget(_app(repository));
  await _settle(tester);
  final moveButton = find.byTooltip('Move today to another day');
  await tester.ensureVisible(moveButton);
  await tester.tap(moveButton);
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  final today = LocalDate.today().iso;

  testWidgets('shows loading, then tasks and weekly summary', (tester) async {
    final repository = _FakeRepository([_task('today', today)]);
    await tester.pumpWidget(_app(repository));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await _settle(tester);
    expect(find.text('today'), findsOneWidget);
    expect(find.text('0% clear'), findsOneWidget);
    expect(find.text('0 of 1 tasks complete'), findsOneWidget);
  });

  testWidgets('shows load error and Retry reloads data', (tester) async {
    final repository = _FakeRepository(const [])
      ..fetchError = StateError('offline');
    await tester.pumpWidget(_app(repository));
    await _settle(tester);
    expect(find.text('Your week could not be loaded.'), findsOneWidget);
    repository.fetchError = null;
    repository.tasks = [_task('recovered', today)];
    await tester.tap(find.text('Retry'));
    await _settle(tester);
    expect(find.text('recovered'), findsOneWidget);
  });

  testWidgets('empty day exposes task creation', (tester) async {
    await tester.pumpWidget(_app(_FakeRepository(const [])));
    await _settle(tester);
    expect(find.text('No tasks yet. A little space is a good thing.'),
        findsOneWidget);
    await _scrollToBottom(tester);
    await tester.tap(find.text('Plan a task'));
    await tester.pumpAndSettle();
    expect(find.text('Give it a place'), findsOneWidget);
  });

  testWidgets('weekday selectors expose labels and selected state',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_app(_FakeRepository([_task('today', today)])));
      await _settle(tester);
      final date = LocalDate.today();
      const weekdays = <String>[
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final weekdayLabel =
          '${weekdays[date.asLocalDateTime.weekday - 1]}, ${date.month}/${date.day}';
      final semantics =
          find.semantics.byFlag(SemanticsFlag.isSelected).evaluate().single;
      expect(semantics.label, contains(weekdayLabel));
      expect(semantics.label, contains('today'));
      expect(semantics.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(semantics.hasFlag(SemanticsFlag.isSelected), isTrue);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('completion control has task-specific accessible label',
      (tester) async {
    final repository = _FakeRepository([_task('today', today)]);
    await tester.pumpWidget(_app(repository));
    await _settle(tester);
    expect(find.byTooltip('Mark today complete'), findsOneWidget);
    final renderBox =
        tester.renderObject<RenderBox>(find.byTooltip('Mark today complete'));
    expect(renderBox.size.width, greaterThanOrEqualTo(44));
    expect(renderBox.size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('Move action opens the sheet and identifies the current date',
      (tester) async {
    await _openMoveSheet(tester, today);
    expect(find.text('Move task'), findsOneWidget);
    final sheet = find.byType(BottomSheet);
    final current = find.descendant(
        of: sheet, matching: find.text(_dateLabel(LocalDate.today())));
    final scrollable = _sheetScrollable(sheet);
    expect(scrollable, findsOneWidget);
    await tester.scrollUntilVisible(current, 80, scrollable: scrollable);
    expect(current, findsOneWidget);
    final currentTile =
        find.ancestor(of: current, matching: find.byType(ListTile));
    expect(tester.widget<ListTile>(currentTile).selected, isTrue);
  });

  testWidgets('all seven weekday destinations are reachable', (tester) async {
    await _openMoveSheet(tester, today);
    final sheet = find.byType(BottomSheet);
    final scrollable = _sheetScrollable(sheet);
    expect(scrollable, findsOneWidget);
    for (final date in _currentWeekDates()) {
      final destination =
          find.descendant(of: sheet, matching: find.text(_dateLabel(date)));
      await tester.scrollUntilVisible(destination, 80, scrollable: scrollable);
      expect(destination, findsOneWidget);
    }
  });

  testWidgets('valid future-date selection updates the repository',
      (tester) async {
    final repository = await _openMoveSheet(tester, today);
    final target = LocalDate.today().addDays(1);
    final sheet = find.byType(BottomSheet);
    final scrollable = _sheetScrollable(sheet);
    expect(scrollable, findsOneWidget);
    final destination =
        find.descendant(of: sheet, matching: find.text(_dateLabel(target)));
    await tester.scrollUntilVisible(destination, 80, scrollable: scrollable);
    await tester.tap(destination);
    await tester.pumpAndSettle();
    expect(repository.updateCalls, 1);
    expect(repository.updatedTaskId, 'today');
    expect(repository.tasks.single.date, target.iso);
  });

  testWidgets('successful movement displays the task on its destination date',
      (tester) async {
    final repository = await _openMoveSheet(tester, today);
    final target = LocalDate.today().addDays(1);
    final sheet = find.byType(BottomSheet);
    final scrollable = _sheetScrollable(sheet);
    expect(scrollable, findsOneWidget);
    final destination =
        find.descendant(of: sheet, matching: find.text(_dateLabel(target)));
    await tester.scrollUntilVisible(destination, 80, scrollable: scrollable);
    await tester.tap(destination);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(
        '^${_weekdays[target.asLocalDateTime.weekday - 1]}, ${target.month}/${target.day}')));
    await tester.pump();
    expect(find.text('today'), findsOneWidget);
    expect(repository.tasks.single.date, target.iso);
  });

  testWidgets('past-date destinations remain disabled', (tester) async {
    await _openMoveSheet(tester, today);
    final todayDate = LocalDate.today();
    final sheet = find.byType(BottomSheet);
    final scrollable = _sheetScrollable(sheet);
    expect(scrollable, findsOneWidget);
    for (final date in _currentWeekDates()
        .where((date) => date.iso.compareTo(todayDate.iso) < 0)) {
      final destination =
          find.descendant(of: sheet, matching: find.text(_dateLabel(date)));
      await tester.scrollUntilVisible(destination, 80, scrollable: scrollable);
      final tile =
          find.ancestor(of: destination, matching: find.byType(ListTile));
      expect(tester.widget<ListTile>(tile).onTap, isNull);
    }
  });

  testWidgets(
      'edit control identifies the task and delete confirmation is accessible',
      (tester) async {
    final repository = _FakeRepository([_task('today', today)]);
    await tester.pumpWidget(_app(repository));
    await _settle(tester);
    expect(find.byTooltip('Edit today'), findsOneWidget);
    await _scrollToBottom(tester);
    await tester.tap(find.byTooltip('Edit today'));
    await tester.pumpAndSettle();
    final deleteButton = find.text('Delete').first;
    await tester.ensureVisible(deleteButton);
    expect(deleteButton, findsOneWidget);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    final dialog = find.ancestor(
        of: find.text('Delete this task?'), matching: find.byType(AlertDialog));
    expect(dialog, findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text('Cancel')),
        findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text('Delete')),
        findsOneWidget);
    await tester
        .tap(find.descendant(of: dialog, matching: find.text('Cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this task?'), findsNothing);
    expect(repository.deleteCalls, 0);
  });

  testWidgets('running Focus task cannot open the edit form', (tester) async {
    final task = _task('focused', today);
    await tester.pumpWidget(_appWithFocus(_FakeRepository([task]), task));
    await _settle(tester);
    final edit = find.byTooltip('Edit focused');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pump();
    expect(find.text('Tune the details'), findsNothing);
    expect(
        find.text(
            "This task can't be changed while its Focus session is active."),
        findsOneWidget);
  });

  testWidgets('paused Focus task cannot open the edit form', (tester) async {
    final task = _task('paused', today);
    await tester
        .pumpWidget(_appWithFocus(_FakeRepository([task]), task, paused: true));
    await _settle(tester);
    final edit = find.byTooltip('Edit paused');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pump();
    expect(find.text('Tune the details'), findsNothing);
    expect(
        find.text(
            "This task can't be changed while its Focus session is active."),
        findsOneWidget);
  });

  testWidgets('completed Focus session allows editing again', (tester) async {
    final task = _task('completed', today);
    await tester.pumpWidget(
        _appWithFocus(_FakeRepository([task]), task, completed: true));
    await _settle(tester);
    final edit = find.byTooltip('Edit completed');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text('Tune the details'), findsOneWidget);
  });

  testWidgets('unrelated task remains editable during Focus', (tester) async {
    final focused = _task('focused', today);
    final unrelated = _task('unrelated', today);
    await tester.pumpWidget(
        _appWithFocus(_FakeRepository([focused, unrelated]), focused));
    await _settle(tester);
    final edit = find.byTooltip('Edit unrelated');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text('Tune the details'), findsOneWidget);
  });
}
