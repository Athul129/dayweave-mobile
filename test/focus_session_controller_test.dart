import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dayweave_mobile/features/focus/application/focus_session_controller.dart';
import 'package:dayweave_mobile/features/focus/presentation/focus_screen.dart';
import 'package:dayweave_mobile/models/task.dart';

Task _task({int minutes = 1, bool done = false}) => Task(
      id: 'task-1',
      userId: 'user-1',
      title: 'Focus task',
      note: 'A clear next step.',
      time: '09:00',
      minutes: minutes,
      energy: TaskEnergy.deep,
      done: done,
      section: TaskSection.morning,
      date: '2026-10-23',
    );

void main() {
  test('starts with the selected task planned duration', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(focusSessionProvider.notifier);
    final start = DateTime(2026, 10, 23, 9);

    controller.start(_task(minutes: 2), now: start);

    expect(controller.state.task?.id, 'task-1');
    expect(controller.state.plannedDurationSeconds, 120);
    expect(controller.state.remainingSeconds, 120);
    expect(controller.state.isRunning, isTrue);
  });

  test('derives countdown progression and completes at zero', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(focusSessionProvider.notifier);
    final start = DateTime(2026, 10, 23, 9);
    controller.start(_task(minutes: 1), now: start);

    controller.tick(start.add(const Duration(seconds: 25)));
    expect(controller.state.remainingSeconds, 35);
    controller.tick(start.add(const Duration(minutes: 1)));
    expect(controller.state.remainingSeconds, 0);
    expect(controller.state.isCompleted, isTrue);
  });

  test('pause freezes remaining time and resume continues it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(focusSessionProvider.notifier);
    final start = DateTime(2026, 10, 23, 9);
    controller.start(_task(minutes: 2), now: start);
    final pausedAt = start.add(const Duration(seconds: 30));

    controller.pause(now: pausedAt);
    expect(controller.state.remainingSeconds, 90);
    expect(controller.state.isPaused, isTrue);
    controller.resume(now: pausedAt.add(const Duration(seconds: 20)));
    expect(controller.state.isRunning, isTrue);
    expect(controller.state.pausedAt, isNull);
    expect(controller.state.remainingSeconds, 90);
    controller.tick(pausedAt.add(const Duration(seconds: 50)));
    expect(controller.state.remainingSeconds, 60);
  });

  test('complete stops a running session at the completion boundary', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(focusSessionProvider.notifier);

    controller.start(_task(minutes: 2), now: DateTime(2026, 10, 23, 9));
    controller.complete();

    expect(controller.state.isCompleted, isTrue);
    expect(controller.state.remainingSeconds, 0);
    expect(controller.state.task?.id, 'task-1');
  });

  test('complete works for a paused session without losing the task', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(focusSessionProvider.notifier);
    final start = DateTime(2026, 10, 23, 9);

    controller.start(_task(minutes: 2), now: start);
    controller.pause(now: start.add(const Duration(seconds: 30)));
    controller.complete();

    expect(controller.state.isCompleted, isTrue);
    expect(controller.state.remainingSeconds, 0);
    expect(controller.state.task?.id, 'task-1');
    expect(controller.state.pausedAt, isNull);
  });

  test('repeated completion keeps one session identity', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(focusSessionProvider.notifier);

    controller.start(_task(minutes: 2), now: DateTime(2026, 10, 23, 9));
    final sessionId = controller.state.sessionId;
    controller.complete();
    controller.complete();

    expect(controller.state.sessionId, sessionId);
    expect(controller.state.isCompleted, isTrue);
  });

  test('continue after completion starts a five-minute continuation', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(focusSessionProvider.notifier);
    final now = DateTime(2026, 10, 23, 9);

    controller.start(_task(minutes: 2), now: now);
    controller.complete();
    controller.continueForFiveMinutes(now: now.add(const Duration(minutes: 2)));

    expect(controller.state.isRunning, isTrue);
    expect(controller.state.remainingSeconds, 300);
    expect(
        controller.state.sessionId,
        matches(RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
  });

  test(
      'restarting the same active task preserves its session and remaining time',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(focusSessionProvider.notifier);
    final start = DateTime(2026, 10, 23, 9);

    controller.start(_task(minutes: 2), now: start);
    controller.tick(start.add(const Duration(seconds: 30)));
    final sessionId = controller.state.sessionId;
    final remaining = controller.state.remainingSeconds;
    controller.start(_task(minutes: 2),
        now: start.add(const Duration(minutes: 1)));

    expect(controller.state.sessionId, sessionId);
    expect(controller.state.remainingSeconds, remaining);
    expect(controller.state.isRunning, isTrue);
  });

  test('does not start a session without a valid task', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(focusSessionProvider.notifier);

    controller.start(null);
    expect(controller.state.hasTask, isFalse);
    expect(controller.state.status, FocusSessionStatus.idle);
    controller.start(_task(done: true));
    expect(controller.state.hasTask, isFalse);
  });

  testWidgets('Exit and Android Back open the same confirmation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ProviderScope(
                child: FocusScreen(task: _task()),
              ),
            ),
          ),
          child: const Text('Open focus'),
        ),
      ),
    ));
    await tester.tap(find.text('Open focus'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final exitButton = find.widgetWithText(OutlinedButton, 'Exit');
    expect(exitButton, findsOneWidget);
    expect(
        tester.getRect(exitButton).right,
        lessThanOrEqualTo(
            tester.view.physicalSize.width / tester.view.devicePixelRatio));
    await tester.tap(exitButton);
    await tester.pump();
    expect(find.text('Leave focus?'), findsOneWidget);
    await tester.tap(find.text('Keep focusing'));
    await tester.pump();
    expect(find.text('Leave focus?'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Leave focus?'), findsOneWidget);
  });

  testWidgets('Leave focus dismisses the Focus route', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ProviderScope(
                child: FocusScreen(task: _task()),
              ),
            ),
          ),
          child: const Text('Open focus'),
        ),
      ),
    ));
    await tester.tap(find.text('Open focus'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final exitButton = find.widgetWithText(OutlinedButton, 'Exit');
    expect(exitButton, findsOneWidget);
    expect(
        tester.getRect(exitButton).right,
        lessThanOrEqualTo(
            tester.view.physicalSize.width / tester.view.devicePixelRatio));
    await tester.tap(exitButton);
    await tester.pump();
    await tester.tap(find.text('Leave focus'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Open focus'), findsOneWidget);
    expect(find.text('Leave focus?'), findsNothing);
  });
}
