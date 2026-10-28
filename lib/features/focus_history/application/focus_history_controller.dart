import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_time/dayweave_date_time.dart';
import '../../../features/auth/application/current_user_provider.dart';
import '../../../models/domain_models.dart';
import '../../../repositories/focus_repository.dart';
import '../../../services/providers.dart';

enum FocusHistoryPeriod { allTime, thisWeek, thisMonth }

class FocusHistoryDayGroup {
  const FocusHistoryDayGroup({required this.date, required this.sessions});

  final LocalDate date;
  final List<FocusSession> sessions;
}

class FocusHistoryState {
  const FocusHistoryState({
    required this.asOf,
    this.sessions = const [],
    this.period = FocusHistoryPeriod.allTime,
    this.isLoading = true,
    this.error,
  });

  final DateTime asOf;
  final List<FocusSession> sessions;
  final FocusHistoryPeriod period;
  final bool isLoading;
  final Object? error;

  List<FocusSession> get filteredSessions {
    final start = switch (period) {
      FocusHistoryPeriod.allTime => null,
      FocusHistoryPeriod.thisWeek => _weekStart(asOf),
      FocusHistoryPeriod.thisMonth => DateTime(asOf.year, asOf.month),
    };
    final endExclusive = switch (period) {
      FocusHistoryPeriod.allTime => null,
      FocusHistoryPeriod.thisWeek => DateTime(
        _weekStart(asOf).year,
        _weekStart(asOf).month,
        _weekStart(asOf).day + 7,
      ),
      FocusHistoryPeriod.thisMonth => DateTime(asOf.year, asOf.month + 1),
    };

    if (start == null || endExclusive == null) return sessions;
    return sessions
        .where((session) {
          final completedAt = session.completedAt.value.toLocal();
          return !completedAt.isBefore(start) &&
              completedAt.isBefore(endExclusive);
        })
        .toList(growable: false);
  }

  int get completedCount => filteredSessions.length;

  int get plannedSeconds => filteredSessions.fold<int>(
    0,
    (total, session) => total + session.plannedDurationSeconds,
  );

  int get pausedSeconds => filteredSessions.fold<int>(
    0,
    (total, session) => total + session.pausedSeconds,
  );

  List<FocusHistoryDayGroup> get dayGroups {
    final groups = <LocalDate, List<FocusSession>>{};
    for (final session in filteredSessions) {
      final completedAt = session.completedAt.value.toLocal();
      final date = LocalDate(
        completedAt.year,
        completedAt.month,
        completedAt.day,
      );
      groups.putIfAbsent(date, () => <FocusSession>[]).add(session);
    }
    return groups.entries
        .map(
          (entry) => FocusHistoryDayGroup(
            date: entry.key,
            sessions: List.unmodifiable(entry.value),
          ),
        )
        .toList(growable: false);
  }

  String groupLabel(LocalDate date) {
    final today = LocalDate(asOf.year, asOf.month, asOf.day);
    final yesterdayDate = DateTime(asOf.year, asOf.month, asOf.day - 1);
    final yesterday = LocalDate(
      yesterdayDate.year,
      yesterdayDate.month,
      yesterdayDate.day,
    );
    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
  }
}

DateTime _weekStart(DateTime date) {
  final localMidnight = DateTime(date.year, date.month, date.day);
  return DateTime(
    localMidnight.year,
    localMidnight.month,
    localMidnight.day - (localMidnight.weekday - DateTime.monday),
  );
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatFocusDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  if (minutes == 0) return '$remainingSeconds sec';
  if (remainingSeconds == 0) return '$minutes min';
  return '$minutes min $remainingSeconds sec';
}

final focusHistoryProvider =
    NotifierProvider<FocusHistoryController, FocusHistoryState>(
      FocusHistoryController.new,
    );

class FocusHistoryController extends Notifier<FocusHistoryState> {
  FocusHistoryController({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  late final FocusRepository _repository;
  int _requestVersion = 0;

  @override
  FocusHistoryState build() {
    _repository = ref.watch(focusRepositoryProvider);
    return FocusHistoryState(asOf: _clock());
  }

  void selectPeriod(FocusHistoryPeriod period) {
    state = FocusHistoryState(
      asOf: _clock(),
      sessions: state.sessions,
      period: period,
      isLoading: state.isLoading,
      error: state.error,
    );
  }

  Future<void> load() async {
    final requestVersion = ++_requestVersion;
    final userId = ref.read(currentUserIdProvider);
    state = FocusHistoryState(
      asOf: _clock(),
      period: state.period,
      isLoading: userId != null,
    );

    if (userId == null) return;

    try {
      final sessions = await _repository.fetchForUser(userId);
      if (requestVersion != _requestVersion ||
          ref.read(currentUserIdProvider) != userId) {
        return;
      }
      final orderedSessions = sessions.asMap().entries.toList()
        ..sort((left, right) {
          final byCompletion = right.value.completedAt.value.compareTo(
            left.value.completedAt.value,
          );
          return byCompletion == 0
              ? left.key.compareTo(right.key)
              : byCompletion;
        });
      state = FocusHistoryState(
        asOf: _clock(),
        sessions: List.unmodifiable(
          orderedSessions.map((entry) => entry.value),
        ),
        period: state.period,
        isLoading: false,
      );
    } catch (error) {
      if (requestVersion != _requestVersion ||
          ref.read(currentUserIdProvider) != userId) {
        return;
      }
      state = FocusHistoryState(
        asOf: _clock(),
        period: state.period,
        isLoading: false,
        error: error,
      );
    }
  }
}
