import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:dayweave_mobile/features/today/presentation/today_screen.dart';

void main() {
  test('Today refresh awaits all Today data reloads', () async {
    final calls = <String>[];
    final taskGate = Completer<void>();
    final intentionGate = Completer<void>();
    final reflectionGate = Completer<void>();
    final focusGate = Completer<void>();

    final refresh = refreshTodayData(
      loadTasks: () async {
        calls.add('tasks-started');
        await taskGate.future;
        calls.add('tasks-completed');
      },
      loadIntention: () async {
        calls.add('intention-started');
        await intentionGate.future;
        calls.add('intention-completed');
      },
      loadReflection: () async {
        calls.add('reflection-started');
        await reflectionGate.future;
        calls.add('reflection-completed');
      },
      loadFocusSummary: () async {
        calls.add('focus-started');
        await focusGate.future;
        calls.add('focus-completed');
      },
    );

    await Future<void>.delayed(Duration.zero);
    expect(calls, [
      'tasks-started',
      'intention-started',
      'reflection-started',
      'focus-started',
    ]);
    taskGate.complete();
    intentionGate.complete();
    reflectionGate.complete();
    focusGate.complete();
    await refresh;
    expect(
        calls,
        containsAllInOrder([
          'tasks-started',
          'intention-started',
          'reflection-started',
          'focus-started',
          'tasks-completed',
          'intention-completed',
          'reflection-completed',
          'focus-completed',
        ]));
  });
}
