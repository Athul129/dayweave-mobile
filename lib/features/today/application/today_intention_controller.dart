import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_time/dayweave_date_time.dart';
import '../../../features/auth/application/current_user_provider.dart';
import '../../../repositories/intention_repository.dart';
import '../../../services/providers.dart';

const defaultDailyIntention = 'Make room for one thing that matters.';

final todayIntentionProvider = NotifierProvider<TodayIntentionController, TodayIntentionState>(TodayIntentionController.new);

class TodayIntentionState {
  const TodayIntentionState({this.value = defaultDailyIntention, this.isLoading = false, this.isSaving = false, this.error});
  final String value;
  final bool isLoading;
  final bool isSaving;
  final Object? error;
  TodayIntentionState copyWith({String? value, bool? isLoading, bool? isSaving, Object? error = _unset}) => TodayIntentionState(value: value ?? this.value, isLoading: isLoading ?? this.isLoading, isSaving: isSaving ?? this.isSaving, error: identical(error, _unset) ? this.error : error);
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
    state = state.copyWith(isLoading: true, error: null);
    try {
      final value = await _repository.fetch(userId, LocalDate.today().iso);
      state = state.copyWith(value: value?.intention ?? defaultDailyIntention, isLoading: false, error: null);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  void update(String value) {
    final version = ++_version;
    state = state.copyWith(value: value, isSaving: true, error: null);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;
      final date = LocalDate.today().iso;
      final request = _writeQueue.then((_) async {
        await _repository.save(userId, date, value);
        if (version == _version) state = state.copyWith(isSaving: false, error: null);
      });
      _writeQueue = request.then<void>((_) {}, onError: (_, __) {});
      request.catchError((Object error) {
        if (version == _version) state = state.copyWith(isSaving: false, error: error);
      });
    });
  }
}
