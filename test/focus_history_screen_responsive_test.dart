import 'dart:ui' as ui;

import 'package:dayweave_mobile/core/date_time/dayweave_date_time.dart';
import 'package:dayweave_mobile/features/auth/application/current_user_provider.dart';
import 'package:dayweave_mobile/features/focus_history/application/focus_history_controller.dart';
import 'package:dayweave_mobile/features/focus_history/presentation/focus_history_screen.dart';
import 'package:dayweave_mobile/models/domain_models.dart';
import 'package:dayweave_mobile/repositories/focus_repository.dart';
import 'package:dayweave_mobile/services/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFocusRepository implements FocusRepository {
  _FakeFocusRepository(this.sessions);

  List<FocusSession> sessions;
  Object? error;

  @override
  Future<List<FocusSession>> fetchForUser(String userId) {
    final failure = error;
    if (failure != null) return Future.error(failure);
    return Future.value(sessions);
  }

  @override
  Future<FocusSession> saveCompleted(
    String userId,
    Map<String, dynamic> draft,
  ) =>
      throw UnimplementedError();
}

FocusSession _session(
  String id, {
  String? title,
  int plannedSeconds = 600,
  int pausedSeconds = 0,
}) {
  final completedAt = DateTime(2026, 10, 14, 12).toUtc();
  return FocusSession(
    id: id,
    sessionId: 'session-$id',
    userId: 'user-7',
    taskId: 'task-$id',
    taskTitle: title ?? 'Task $id',
    taskDate: null,
    plannedDurationSeconds: plannedSeconds,
    startedAt: DayweaveTimestamp(
      completedAt.subtract(const Duration(minutes: 30)),
    ),
    completedAt: DayweaveTimestamp(completedAt),
    pausedSeconds: pausedSeconds,
    createdAt: DayweaveTimestamp(completedAt),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeFocusRepository repository, {
  double width = 360,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        focusRepositoryProvider.overrideWithValue(repository),
        currentUserIdProvider.overrideWithValue('user-7'),
        focusHistoryProvider.overrideWith(
          () => FocusHistoryController(
            clock: () => DateTime(2026, 10, 14, 12),
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: const FocusHistoryScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const longTitle =
      'A very long focus task title that must remain constrained within the session card';
  final populatedSessions = [
    _session(
      'long',
      title: longTitle,
      plannedSeconds: 999999,
      pausedSeconds: 54321,
    ),
    _session('same-day-2', plannedSeconds: 3600, pausedSeconds: 1200),
    _session('same-day-3', plannedSeconds: 7200, pausedSeconds: 1800),
  ];

  for (final width in [320.0, 360.0]) {
    testWidgets('has no layout exception at ${width.toInt()} logical pixels',
        (tester) async {
      await _pumpScreen(
        tester,
        _FakeFocusRepository(populatedSessions),
        width: width,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(DropdownButton<FocusHistoryPeriod>), findsOneWidget);
      expect(
          find.textContaining('A very long focus task title'), findsOneWidget);
      expect(find.text('16666 min 39 sec'), findsOneWidget);
    });
  }

  for (final scale in [1.3, 1.5, 2.0]) {
    testWidgets('has no layout exception at ${scale}x text scale',
        (tester) async {
      await _pumpScreen(
        tester,
        _FakeFocusRepository(populatedSessions),
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('All time'), findsOneWidget);
      expect(find.text(longTitle), findsOneWidget);
    });
  }

  testWidgets('filter dropdown and session content expose semantics',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      await _pumpScreen(tester, _FakeFocusRepository(populatedSessions));

      final dropdown = tester.getSemantics(
        find.byType(DropdownButton<FocusHistoryPeriod>),
      );
      expect(dropdown.label, isNotEmpty);
      expect(
        dropdown.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      expect(dropdown.label, contains('All time'));

      await tester.tap(find.byType(DropdownButton<FocusHistoryPeriod>));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('This week')).label,
        contains('This week'),
      );
      await tester.tap(find.text('This week').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.byType(DropdownButton<FocusHistoryPeriod>))
            .label,
        contains('This week'),
      );

      await tester.tap(find.byType(DropdownButton<FocusHistoryPeriod>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('This month').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.byType(DropdownButton<FocusHistoryPeriod>))
            .label,
        contains('This month'),
      );

      final title = tester.getSemantics(find.text(longTitle));
      expect(title.label, contains(longTitle));
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('filter dropdown meets the minimum touch target', (tester) async {
    await _pumpScreen(tester, _FakeFocusRepository(populatedSessions));

    final box = tester.renderObject<RenderBox>(
      find.byType(DropdownButton<FocusHistoryPeriod>),
    );
    expect(box.size.width, greaterThanOrEqualTo(44));
    expect(box.size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('full-screen retry meets the minimum touch target',
      (tester) async {
    final repository = _FakeFocusRepository([])..error = StateError('offline');
    await _pumpScreen(tester, repository);

    final retry = find.widgetWithText(OutlinedButton, 'Try again');
    expect(retry, findsOneWidget);
    final box = tester.renderObject<RenderBox>(retry);
    expect(box.size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('refresh failure keeps history and exposes an accessible retry',
      (tester) async {
    final repository = _FakeFocusRepository([_session('loaded')]);
    await _pumpScreen(tester, repository);
    repository.error = StateError('offline');

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();

    expect(find.text('Task loaded'), findsOneWidget);
    final retry = find.widgetWithText(TextButton, 'Retry');
    expect(retry, findsOneWidget);
    final box = tester.renderObject<RenderBox>(retry);
    expect(box.size.height, greaterThanOrEqualTo(44));
    expect(
      tester.getSemantics(retry).label,
      'Retry',
    );
  });
}
