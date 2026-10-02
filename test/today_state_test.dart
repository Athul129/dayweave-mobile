import 'package:flutter_test/flutter_test.dart';

import 'package:dayweave_mobile/core/date_time/dayweave_date_time.dart';
import 'package:dayweave_mobile/features/today/application/today_state.dart';
import 'package:dayweave_mobile/models/task.dart';

Task task(String id, {String title = 'Task', String note = 'Note', String date = '2026-10-02', bool done = false, TaskEnergy energy = TaskEnergy.light, TaskSection section = TaskSection.morning, int minutes = 30}) => Task(
      id: id,
      userId: 'user',
      title: title,
      note: note,
      time: '09:00',
      minutes: minutes,
      energy: energy,
      done: done,
      section: section,
      date: date,
    );

TodaySelectors selectors(List<Task> tasks, {String? activeTaskId, String searchQuery = '', TodayStatusFilter status = TodayStatusFilter.all, TodayEnergyFilter energy = TodayEnergyFilter.all, TodaySectionFilter section = TodaySectionFilter.all}) => TodaySelectors(TodayState(
      date: LocalDate.parse('2026-10-02'),
      tasks: tasks,
      activeTaskId: activeTaskId,
      searchQuery: searchQuery,
      statusFilter: status,
      energyFilter: energy,
      sectionFilter: section,
    ));

void main() {
  test('uses the local calendar date', () {
    expect(LocalDate.parse('2026-10-02').iso, '2026-10-02');
  });

  test('derives sections, progress, and durations', () {
    final value = selectors([
      task('1', section: TaskSection.morning, done: true, minutes: 20),
      task('2', section: TaskSection.midday, minutes: 40),
      task('3', section: TaskSection.afternoon, minutes: 30),
    ]);
    expect(value.tasksFor(TaskSection.morning).map((item) => item.id), ['1']);
    expect(value.tasksFor(TaskSection.midday).map((item) => item.id), ['2']);
    expect(value.tasksFor(TaskSection.afternoon).map((item) => item.id), ['3']);
    expect(value.completedCount, 1);
    expect(value.totalCount, 3);
    expect(value.progress, 33);
    expect(value.remainingMinutes, 70);
    expect(value.totalPlannedMinutes, 90);
    expect(selectors(const []).progress, 0);
  });

  test('search is trimmed, case-insensitive, and searches title and note', () {
    final value = selectors([task('1', title: 'Write Report'), task('2', note: 'Call the TEAM')], searchQuery: '  team ');
    expect(value.filteredTasks.map((item) => item.id), ['2']);
  });

  test('composes status, energy, and section filters', () {
    final value = selectors([
      task('1', done: false, energy: TaskEnergy.deep, section: TaskSection.morning),
      task('2', done: true, energy: TaskEnergy.deep, section: TaskSection.morning),
      task('3', done: false, energy: TaskEnergy.social, section: TaskSection.morning),
    ], status: TodayStatusFilter.active, energy: TodayEnergyFilter.deep, section: TodaySectionFilter.morning);
    expect(value.filteredTasks.map((item) => item.id), ['1']);
  });

  test('up next prefers active, then unfinished, then first task', () {
    expect(selectors([task('1', done: false), task('2', done: false)], activeTaskId: '2').upNext!.id, '2');
    expect(selectors([task('1', done: true), task('2', done: false)]).upNext!.id, '2');
    expect(selectors([task('1', done: true), task('2', done: true)]).upNext!.id, '1');
    expect(selectors(const []).upNext, isNull);
  });

  test('validates task drafts and preserves Later contract', () {
    final today = LocalDate.parse('2026-10-02');
    final invalid = TodayTaskDraft(title: ' ', note: '', time: '25:70', minutes: 0, energy: TaskEnergy.light, section: TaskSection.morning, date: today);
    expect(validateTodayTaskDraft(invalid, today).keys, containsAll(['title', 'time', 'minutes']));
    expect(TodayTaskDraft(title: 'x', note: '', time: '16:30', minutes: 30, energy: TaskEnergy.light, section: TaskSection.afternoon, date: today).toDatabase(), containsPair('time', '16:30'));
  });
}
