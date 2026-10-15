import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_time/dayweave_date_time.dart';
import '../../../features/auth/application/current_user_provider.dart';
import '../../../repositories/intention_repository.dart';
import '../../../services/providers.dart';

const defaultDailyIntention = 'Make room for one thing that matters.';

enum TodayIntentionErrorKind { load, save }

final todayIntentionProvider =
    NotifierProvider<TodayIntentionController, TodayIntentionState>(
        TodayIntentionController.new);

class TodayIntentionState {
  const TodayIntentionState(
      {this.value = defaultDailyIntention,
      this.isLoading = false,
      this.isSaving = false,
      this.error,
      this.errorKind});
  final String value;
  final bool isLoading;
  final bool isSaving;
  final Object? error;
  final TodayIntentionErrorKind? errorKind;
  TodayIntentionState copyWith(
          {String? value,
          bool? isLoading,
          bool? isSaving,
          Object? error = _unset,
          Object? errorKind = _unset}) =>
      TodayIntentionState(
          value: value ?? this.value,
          isLoading: isLoading ?? this.isLoading,
          isSaving: isSaving ?? this.isSaving,
          error: identical(error, _unset) ? this.error : error,
          errorKind: identical(errorKind, _unset)
              ? this.errorKind
              : errorKind as TodayIntentionErrorKind?);
}

const _unset = Object();

class TodayIntentionController extends Notifier<TodayIntentionState> {
  late final IntentionRepository _repository;
  Timer? _debounce;
  Future<void> _writeQueue = Future<void>.value();
  int _version = 0;

  @override
  TodayIntentionState build() {
    _repository = ref.watch(intentionRepositoryProvider);
    ref.onDispose(() => _debounce?.cancel());
    Future<void>.microtask(load);
    return const TodayIntentionState();
  }

  Future<void> load() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    state = state.copyWith(isLoading: true, error: null, errorKind: null);
    try {
      final value = await _repository.fetch(userId, LocalDate.today().iso);
      state = state.copyWith(
          value: value?.intention ?? defaultDailyIntention,
          isLoading: false,
          error: null,
          errorKind: null);
    } catch (error) {
      state = state.copyWith(
          isLoading: false,
          error: error,
          errorKind: TodayIntentionErrorKind.load);
    }
  }

  void update(String value) {
    final version = ++_version;
    state = state.copyWith(
        value: value, isSaving: true, error: null, errorKind: null);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        if (version == _version) {
          state = state.copyWith(
              isSaving: false,
              error: StateError('Authentication is required.'),
              errorKind: TodayIntentionErrorKind.save);
        }
        return;
      }
      final date = LocalDate.today().iso;
      final request = _writeQueue.then((_) async {
        try {
          await _repository.save(userId, date, value);
        } catch (error, stackTrace) {
          developer.log(
            'Daily intention save failed.',
            name: 'dayweave.today.intention',
            error: error,
            stackTrace: stackTrace,
          );
          rethrow;
        }
        if (version == _version)
          state = state.copyWith(isSaving: false, error: null, errorKind: null);
      });
      _writeQueue = request.then<void>((_) {}, onError: (_, __) {});
      request.catchError((Object error) {
        if (version == _version)
          state = state.copyWith(
              isSaving: false,
              error: error,
              errorKind: TodayIntentionErrorKind.save);
      });
    });
  }
}
