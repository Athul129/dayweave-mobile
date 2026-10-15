import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dayweave_mobile/features/auth/application/current_user_provider.dart';
import 'package:dayweave_mobile/features/today/application/today_intention_controller.dart';
import 'package:dayweave_mobile/models/domain_models.dart';
import 'package:dayweave_mobile/repositories/intention_repository.dart';
import 'package:dayweave_mobile/services/providers.dart';

class FakeIntentionRepository implements IntentionRepository {
  DailyIntention? value;
  Object? fetchError;
  Object? saveError;
  final List<String> savedValues = [];

  @override
  Future<DailyIntention?> fetch(String userId, String date) async {
    if (fetchError != null) throw fetchError!;
    return value;
  }

  @override
  Future<void> save(String userId, String date, String intention) async {
    if (saveError != null) throw saveError!;
    savedValues.add(intention);
  }
}

ProviderContainer intentionContainer(FakeIntentionRepository repository,
    {String? userId = 'user-1'}) {
  return ProviderContainer(overrides: [
    intentionRepositoryProvider.overrideWithValue(repository),
    currentUserIdProvider.overrideWithValue(userId),
  ]);
}

Future<void> settleDebounce() async {
  await Future<void>.delayed(const Duration(milliseconds: 400));
}

void main() {
  test('load success populates the intention', () async {
    final repository = FakeIntentionRepository();
    final container = intentionContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(todayIntentionProvider.notifier);

    await Future<void>.delayed(Duration.zero);

    expect(controller.state.error, isNull);
    expect(controller.state.isLoading, isFalse);
  });

  test('load failure is distinguished from save failure', () async {
    final repository = FakeIntentionRepository()
      ..fetchError = StateError('load failed');
    final container = intentionContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(todayIntentionProvider.notifier);

    await Future<void>.delayed(Duration.zero);

    expect(controller.state.errorKind, TodayIntentionErrorKind.load);
    expect(controller.state.isSaving, isFalse);
  });

  test('save success clears saving state and persists the latest value',
      () async {
    final repository = FakeIntentionRepository();
    final container = intentionContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(todayIntentionProvider.notifier);

    controller.update('Latest intention');
    await settleDebounce();

    expect(repository.savedValues, ['Latest intention']);
    expect(controller.state.isSaving, isFalse);
    expect(controller.state.error, isNull);
  });

  test('save failure clears saving state and exposes a save error', () async {
    final repository = FakeIntentionRepository()
      ..saveError = StateError('save failed');
    final container = intentionContainer(repository);
    addTearDown(container.dispose);
    final controller = container.read(todayIntentionProvider.notifier);

    controller.update('Unsaved intention');
    await settleDebounce();

    expect(controller.state.isSaving, isFalse);
    expect(controller.state.errorKind, TodayIntentionErrorKind.save);
  });

  test('authentication loss during debounce clears saving state', () async {
    final repository = FakeIntentionRepository();
    final container = intentionContainer(repository, userId: null);
    addTearDown(container.dispose);
    final controller = container.read(todayIntentionProvider.notifier);

    controller.update('Needs authentication');
    await settleDebounce();

    expect(controller.state.isSaving, isFalse);
    expect(controller.state.errorKind, TodayIntentionErrorKind.save);
    expect(repository.savedValues, isEmpty);
  });
}
