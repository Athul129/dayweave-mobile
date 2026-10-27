import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dayweave_mobile/core/date_time/dayweave_date_time.dart';
import 'package:dayweave_mobile/features/auth/application/current_user_provider.dart';
import 'package:dayweave_mobile/features/today/application/today_reflection_controller.dart';
import 'package:dayweave_mobile/features/today/presentation/widgets/today_reflection_screen.dart';
import 'package:dayweave_mobile/models/domain_models.dart';
import 'package:dayweave_mobile/repositories/focus_repository.dart';
import 'package:dayweave_mobile/repositories/reflection_repository.dart';
import 'package:dayweave_mobile/services/providers.dart';

class FakeReflectionRepository implements ReflectionRepository {
  DailyReflection? value;
  Object? fetchError;
  Object? saveError;
  String? fetchedUserId;
  String? fetchedDate;
  String? savedUserId;
  String? savedDate;
  String? savedWentWell;
  String? savedCarryForward;
  int fetchCalls = 0;
  int saveCalls = 0;

  @override
  Future<DailyReflection?> fetch(String userId, String date) async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    fetchedUserId = userId;
    fetchedDate = date;
    return value;
  }

  @override
  Future<DailyReflection> save(
      String userId, String date, String wentWell, String carryForward) async {
    saveCalls++;
    if (saveError != null) throw saveError!;
    savedUserId = userId;
    savedDate = date;
    savedWentWell = wentWell;
    savedCarryForward = carryForward;
    value = DailyReflection(
      id: 'reflection-1',
      userId: userId,
      date: LocalDate.parse(date),
      wentWell: wentWell,
      carryForward: carryForward,
      createdAt: DayweaveTimestamp.now(),
      updatedAt: DayweaveTimestamp.now(),
    );
    return value!;
  }
}

class FakeFocusRepository implements FocusRepository {
  int fetchCalls = 0;

  @override
  Future<List<FocusSession>> fetchForUser(String userId) async {
    fetchCalls++;
    return const [];
  }

  @override
  Future<FocusSession> saveCompleted(
          String userId, Map<String, dynamic> draft) async =>
      throw UnimplementedError();
}

ProviderContainer reflectionContainer(FakeReflectionRepository repository,
        {String? userId = 'user-1', FocusRepository? focusRepository}) =>
    ProviderContainer(overrides: [
      reflectionRepositoryProvider.overrideWithValue(repository),
      focusRepositoryProvider
          .overrideWithValue(focusRepository ?? FakeFocusRepository()),
      currentUserIdProvider.overrideWithValue(userId),
    ]);

void main() {
  test('loads an existing reflection for the authenticated local date',
      () async {
    final repository = FakeReflectionRepository()
      ..value = DailyReflection(
        id: 'reflection-1',
        userId: 'user-1',
        date: LocalDate.today(),
        wentWell: 'Made progress.',
        carryForward: 'Review the notes.',
        createdAt: DayweaveTimestamp.now(),
        updatedAt: DayweaveTimestamp.now(),
      );
    final container = reflectionContainer(
      repository,
      focusRepository: FakeFocusRepository(),
    );
    addTearDown(container.dispose);
    final controller = container.read(todayReflectionProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.load();

    expect(controller.state.wentWell, 'Made progress.');
    expect(controller.state.carryForward, 'Review the notes.');
    expect(repository.fetchedUserId, 'user-1');
    expect(repository.fetchedDate, LocalDate.today().iso);
  });

  test('saves both fields with the authenticated user and local date',
      () async {
    final repository = FakeReflectionRepository();
    final container =
        reflectionContainer(repository, focusRepository: FakeFocusRepository());
    addTearDown(container.dispose);
    final controller = container.read(todayReflectionProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    controller.updateWentWell('  Finished the draft. ');
    controller.updateCarryForward(' Prepare the next step. ');

    await controller.save();

    expect(repository.saveCalls, 1);
    expect(repository.savedUserId, 'user-1');
    expect(repository.savedDate, LocalDate.today().iso);
    expect(repository.savedWentWell, 'Finished the draft.');
    expect(repository.savedCarryForward, 'Prepare the next step.');
    expect(controller.state.isSaving, isFalse);
  });

  test('load and save failures expose distinct recoverable states', () async {
    final repository = FakeReflectionRepository()
      ..fetchError = StateError('load failed')
      ..saveError = StateError('save failed');
    final container = reflectionContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(todayReflectionProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    await controller.load();
    expect(controller.state.errorKind, TodayReflectionErrorKind.load);
    expect(controller.state.isLoading, isFalse);

    controller.updateWentWell('Try again');
    await expectLater(controller.save(), throwsStateError);
    expect(controller.state.errorKind, TodayReflectionErrorKind.save);
    expect(controller.state.isSaving, isFalse);
  });

  test('duplicate saves do not issue concurrent writes', () async {
    final repository = FakeReflectionRepository();
    final container = reflectionContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(todayReflectionProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    controller.updateWentWell('One save');

    final first = controller.save();
    final second = controller.save();
    await Future.wait([first, second]);

    expect(repository.saveCalls, 1);
  });

  testWidgets('reopening Reflection reloads the cached provider',
      (tester) async {
    final repository = FakeReflectionRepository();
    final container = reflectionContainer(
      repository,
      focusRepository: FakeFocusRepository(),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TodayReflectionScreen()),
    ));
    await tester.pump();
    await tester.pump();
    final firstOpenFetches = repository.fetchCalls;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: TodayReflectionScreen(key: ValueKey('reopened')),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(firstOpenFetches, 1);
    expect(repository.fetchCalls, 2);
  });
}
