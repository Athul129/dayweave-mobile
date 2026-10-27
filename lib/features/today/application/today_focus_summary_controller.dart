import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_time/dayweave_date_time.dart';
import '../../../features/auth/application/current_user_provider.dart';
import '../../../repositories/focus_repository.dart';
import '../../../services/providers.dart';

class TodayFocusSummaryState {
  const TodayFocusSummaryState({
    this.sessionCount = 0,
    this.plannedMinutes = 0,
    this.isLoading = false,
    this.error,
  });

  final int sessionCount;
  final int plannedMinutes;
  final bool isLoading;
  final Object? error;

  TodayFocusSummaryState copyWith({
    int? sessionCount,
    int? plannedMinutes,
    bool? isLoading,
    Object? error = _unset,
  }) =>
      TodayFocusSummaryState(
        sessionCount: sessionCount ?? this.sessionCount,
        plannedMinutes: plannedMinutes ?? this.plannedMinutes,
        isLoading: isLoading ?? this.isLoading,
        error: identical(error, _unset) ? this.error : error,
      );
}

const _unset = Object();

final todayFocusSummaryProvider =
    NotifierProvider<TodayFocusSummaryController, TodayFocusSummaryState>(
        TodayFocusSummaryController.new);

class TodayFocusSummaryController extends Notifier<TodayFocusSummaryState> {
  late final FocusRepository _repository;
  int _requestVersion = 0;

  @override
  TodayFocusSummaryState build() {
    _repository = ref.watch(focusRepositoryProvider);
    return const TodayFocusSummaryState();
  }

  Future<void> load() async {
    final userId = ref.read(currentUserIdProvider);
    final date = LocalDate.today();
    final requestVersion = ++_requestVersion;

    if (userId == null) {
      state = state.copyWith(
        isLoading: false,
        sessionCount: 0,
        plannedMinutes: 0,
        error: StateError('Authentication is required.'),
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final sessions = await _repository.fetchForUser(userId);
      if (requestVersion != _requestVersion ||
          ref.read(currentUserIdProvider) != userId ||
          LocalDate.today() != date) {
        return;
      }

      final todaySessions = sessions.where((session) {
        final completedAt = session.completedAt.value.toLocal();
        return LocalDate(
                completedAt.year, completedAt.month, completedAt.day) ==
            date;
      }).toList(growable: false);
      final plannedSeconds = todaySessions.fold<int>(
          0, (total, session) => total + session.plannedDurationSeconds);

      state = state.copyWith(
        sessionCount: todaySessions.length,
        plannedMinutes: (plannedSeconds / 60).round(),
        isLoading: false,
        error: null,
      );
    } catch (error) {
      if (requestVersion != _requestVersion) return;
      state = state.copyWith(isLoading: false, error: error);
    }
  }
}
