import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dayweave_mobile/core/date_time/dayweave_date_time.dart';
import 'package:dayweave_mobile/features/today/application/today_state.dart';
import 'package:dayweave_mobile/features/today/presentation/widgets/today_task_form.dart';

Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  final today = LocalDate.parse('2026-10-02');

  testWidgets('shows a friendly validation error for an empty title',
      (tester) async {
    await tester.pumpWidget(host(TodayTaskForm(
      today: today,
      initial: defaultTodayTaskDraft(today),
      onSave: (_) async => null,
    )));

    final saveButton = find.text('Add to route');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();

    expect(find.text('Give this task a short title.'), findsOneWidget);
  });

  testWidgets('passes the captured title and defaults to the save callback',
      (tester) async {
    TodayTaskDraft? saved;
    await tester.pumpWidget(host(TodayTaskForm(
      today: today,
      initial: defaultTodayTaskDraft(today, title: 'Captured thought'),
      onSave: (draft) async {
        saved = draft;
        return null;
      },
    )));

    final saveButton = find.text('Add to route');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();

    expect(saved?.title, 'Captured thought');
    expect(saved?.time, '16:00');
    expect(saved?.minutes, 30);
    expect(saved?.note, defaultTaskNote);
  });
}
