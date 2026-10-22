import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_time/dayweave_date_time.dart';
import '../../../features/auth/application/current_user_provider.dart';
import '../../../repositories/reflection_repository.dart';
import '../../../services/providers.dart';

enum TodayReflectionErrorKind { load, save }

class TodayReflectionState {
  const TodayReflectionState({
    this.wentWell = '',
    this.carryForward = '',
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.errorKind,
  });

  final String wentWell;
  final String carryForward;
  final bool isLoading;
  final bool isSaving;
  final Object? error;
  final TodayReflectionErrorKind? errorKind;

  TodayReflectionState copyWith({
    String? wentWell,
    String? carryForward,
    bool? isLoading,
    bool? isSaving,
    Object? error = _unset,
    Object? errorKind = _unset,
  }) =>
      TodayReflectionState(
        wentWell: wentWell ?? this.wentWell,
        carryForward: carryForward ?? this.carryForward,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        error: identical(error, _unset) ? this.error : error,
        errorKind: identical(errorKind, _unset)
            ? this.errorKind
            : errorKind as TodayReflectionErrorKind?,
      );
}

const _unset = Object();

final todayReflectionProvider =
    NotifierProvider<TodayReflectionController, TodayReflectionState>(
        TodayReflectionController.new);

class TodayReflectionController extends Notifier<TodayReflectionState> {
  late final ReflectionRepository _repository;
  int _requestVersion = 0;
  Future<void>? _saveRequest;

  @override
  TodayReflectionState build() {
    _repository = ref.watch(reflectionRepositoryProvider);
    return const TodayReflectionState();
  }

  Future<void> load() async {
    if (state.isSaving || _saveRequest != null) return;
    final userId = ref.read(currentUserIdProvider);
    final date = LocalDate.today().iso;
    final requestVersion = ++_requestVersion;
    if (userId == null) {
      state = state.copyWith(
          isLoading: false,
          error: StateError('Authentication is required.'),
          errorKind: TodayReflectionErrorKind.load);
      return;
    }
    state = state.copyWith(isLoading: true, error: null, errorKind: null);
    try {
      final reflection = await _repository.fetch(userId, date);
      if (requestVersion != _requestVersion ||
          ref.read(currentUserIdProvider) != userId ||
          LocalDate.today().iso != date) return;
      state = state.copyWith(
        wentWell: reflection?.wentWell ?? '',
        carryForward: reflection?.carryForward ?? '',
        isLoading: false,
        error: null,
        errorKind: null,
      );
    } catch (error) {
      if (requestVersion != _requestVersion) return;
      state = state.copyWith(
          isLoading: false,
          error: error,
          errorKind: TodayReflectionErrorKind.load);
    }
  }

  void updateWentWell(String value) =>
      state = state.copyWith(wentWell: value, error: null, errorKind: null);

  void updateCarryForward(String value) =>
      state = state.copyWith(carryForward: value, error: null, errorKind: null);

  Future<void> save() async {
    if (state.isLoading || state.isSaving || _saveRequest != null) return;
    final userId = ref.read(currentUserIdProvider);
    final date = LocalDate.today().iso;
    if (userId == null) {
      state = state.copyWith(
          error: StateError('Authentication is required.'),
          errorKind: TodayReflectionErrorKind.save);
      return;
    }
    final requestVersion = ++_requestVersion;
    final wentWell = state.wentWell.trim();
    final carryForward = state.carryForward.trim();
    state = state.copyWith(isSaving: true, error: null, errorKind: null);
    final request = _repository.save(userId, date, wentWell, carryForward);
    final saveRequest = request.then<void>((reflection) {
      if (requestVersion == _requestVersion &&
          ref.read(currentUserIdProvider) == userId &&
          LocalDate.today().iso == date) {
        state = state.copyWith(
            wentWell: reflection.wentWell,
            carryForward: reflection.carryForward,
            isSaving: false,
            error: null,
            errorKind: null);
      }
    }).catchError((Object error) {
      if (requestVersion == _requestVersion) {
        state = state.copyWith(
            isSaving: false,
            error: error,
            errorKind: TodayReflectionErrorKind.save);
      }
      throw error;
    });
    _saveRequest = saveRequest;
    try {
      await saveRequest;
    } finally {
      _saveRequest = null;
    }
  }
}
