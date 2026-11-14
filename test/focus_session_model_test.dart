import 'package:dayweave_mobile/models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({
  Object plannedDurationSeconds = 600,
  Object pausedSeconds = 30,
}) =>
    {
      'id': 'row-1',
      'session_id': 'session-1',
      'user_id': 'user-1',
      'task_id': 'task-1',
      'task_title': 'Focus task',
      'task_date': '2026-10-14',
      'planned_duration_seconds': plannedDurationSeconds,
      'started_at': '2026-10-14T10:00:00.000Z',
      'completed_at': '2026-10-14T10:30:00.000Z',
      'paused_seconds': pausedSeconds,
      'created_at': '2026-10-14T10:30:00.000Z',
    };

void main() {
  test('parses integer duration fields', () {
    final session = FocusSession.fromDatabase(_row());

    expect(session.plannedDurationSeconds, 600);
    expect(session.pausedSeconds, 30);
  });

  test('parses zero duration fields', () {
    final session = FocusSession.fromDatabase(
      _row(plannedDurationSeconds: 0, pausedSeconds: 0),
    );

    expect(session.plannedDurationSeconds, 0);
    expect(session.pausedSeconds, 0);
  });

  test('rejects unsupported non-integer duration values', () {
    expect(
      () => FocusSession.fromDatabase(_row(plannedDurationSeconds: 600.0)),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => FocusSession.fromDatabase(_row(pausedSeconds: 30.0)),
      throwsA(isA<TypeError>()),
    );
  });

  test('rejects missing duration fields', () {
    final row = _row()..remove('planned_duration_seconds');

    expect(() => FocusSession.fromDatabase(row), throwsA(isA<TypeError>()));
  });

  test('rejects malformed duration fields', () {
    expect(
      () => FocusSession.fromDatabase(_row(pausedSeconds: '30')),
      throwsA(isA<TypeError>()),
    );
  });
}
