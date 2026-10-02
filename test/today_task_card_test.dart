import 'package:dayweave_mobile/core/theme/dayweave_theme.dart';
import 'package:dayweave_mobile/features/today/presentation/widgets/today_task_card.dart';
import 'package:dayweave_mobile/models/task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Task _task({bool done = false}) => Task(
      id: 'task-1',
      userId: 'user-1',
      title: 'Write the daily plan',
      note: 'Start with the next small step.',
      time: '09:00',
      minutes: 30,
      energy: TaskEnergy.deep,
      done: done,
      section: TaskSection.morning,
      date: '2026-10-02',
    );

void main() {
  testWidgets('selects and completes a visible Today task', (tester) async {
    var selected = false;
    var toggled = false;
    await tester.pumpWidget(MaterialApp(
      theme: DayweaveTheme.light(),
      home: Scaffold(
        body: TodayTaskCard(
          task: _task(),
          selected: false,
          onSelect: () => selected = true,
          onToggleComplete: () => toggled = true,
        ),
      ),
    ));

    expect(find.text('Write the daily plan'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('Deep'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    expect(toggled, isTrue);
    await tester.tap(find.text('Write the daily plan'));
    expect(selected, isTrue);
  });
}
