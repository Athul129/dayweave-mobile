import 'package:flutter_test/flutter_test.dart';

import 'package:dayweave_mobile/features/today/presentation/today_screen.dart';

void main() {
  test('Today refresh awaits task and intention reloads', () async {
    final calls = <String>[];
    var taskCompleted = false;
    var intentionCompleted = false;

    final refresh = refreshTodayData(
      loadTasks: () async {
        calls.add('tasks-started');
        await Future<void>.delayed(Duration.zero);
        taskCompleted = true;
        calls.add('tasks-completed');
      },
      loadIntention: () async {
        calls.add('intention-started');
        await Future<void>.delayed(Duration.zero);
        intentionCompleted = true;
        calls.add('intention-completed');
      },
    );

    expect(taskCompleted, isFalse);
    expect(intentionCompleted, isFalse);
    await refresh;
    expect(taskCompleted, isTrue);
    expect(intentionCompleted, isTrue);
    expect(
        calls,
        containsAllInOrder([
          'tasks-started',
          'intention-started',
          'tasks-completed',
          'intention-completed',
        ]));
  });
}
