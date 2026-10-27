import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/task.dart';

enum FocusSessionStatus { idle, running, paused, completed }

class FocusSessionState {
  const FocusSessionState({
    this.task,
    this.sessionId,
    this.plannedDurationSeconds = 0,
    this.startAt,
    this.endAt,
    this.remainingSeconds = 0,
    this.status = FocusSessionStatus.idle,
    this.pausedAt,
    this.pausedSeconds = 0,
  });

  final Task? task;
  final String? sessionId;
  final int plannedDurationSeconds;
  final DateTime? startAt;
  final DateTime? endAt;
  final int remainingSeconds;
  final FocusSessionStatus status;
  final DateTime? pausedAt;
  final int pausedSeconds;

  bool get hasTask => task != null;
  bool get isRunning => status == FocusSessionStatus.running;
  bool get isPaused => status == FocusSessionStatus.paused;
  bool get isCompleted => status == FocusSessionStatus.completed;

  FocusSessionState copyWith({
    Task? task,
    String? sessionId,
    int? plannedDurationSeconds,
    DateTime? startAt,
    DateTime? endAt,
    int? remainingSeconds,
    FocusSessionStatus? status,
    DateTime? pausedAt,
    int? pausedSeconds,
    bool clearPausedAt = false,
  }) =>
      FocusSessionState(
        task: task ?? this.task,
        sessionId: sessionId ?? this.sessionId,
        plannedDurationSeconds:
            plannedDurationSeconds ?? this.plannedDurationSeconds,
        startAt: startAt ?? this.startAt,
        endAt: endAt ?? this.endAt,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        status: status ?? this.status,
        pausedAt: clearPausedAt ? null : pausedAt ?? this.pausedAt,
        pausedSeconds: pausedSeconds ?? this.pausedSeconds,
      );
}

final focusSessionProvider =
    NotifierProvider<FocusSessionController, FocusSessionState>(
        FocusSessionController.new);

class FocusSessionController extends Notifier<FocusSessionState> {
  Timer? _timer;

  @override
  FocusSessionState build() {
    ref.onDispose(_stopTimer);
    return const FocusSessionState();
  }

  void start(Task? task, {DateTime? now}) {
    if (task != null &&
        state.task?.id == task.id &&
        !state.isCompleted &&
        state.hasTask) {
      if (state.isPaused) {
        resume(now: now);
      }
      return;
    }
    _stopTimer();
    if (task == null || task.done) {
      state = const FocusSessionState();
      return;
    }
    final started = now ?? DateTime.now();
    final planned = task.minutes * 60;
    state = FocusSessionState(
      task: task,
      sessionId: _newSessionId(),
      plannedDurationSeconds: planned,
      startAt: started,
      endAt: started.add(Duration(seconds: planned)),
      remainingSeconds: planned,
      status: FocusSessionStatus.running,
    );
    _startTimer();
  }

  void pause({DateTime? now}) {
    if (!state.isRunning) return;
    final current = now ?? DateTime.now();
    tick(current);
    if (!state.isRunning) return;
    _stopTimer();
    state = state.copyWith(
      status: FocusSessionStatus.paused,
      pausedAt: current,
    );
  }

  void resume({DateTime? now}) {
    if (!state.isPaused) return;
    final resumed = now ?? DateTime.now();
    final remaining = state.remainingSeconds;
    final pausedFor = state.pausedAt == null
        ? 0
        : resumed.difference(state.pausedAt!).inSeconds;
    state = state.copyWith(
      startAt: resumed,
      endAt: resumed.add(Duration(seconds: remaining)),
      status: remaining == 0
          ? FocusSessionStatus.completed
          : FocusSessionStatus.running,
      clearPausedAt: true,
      pausedSeconds: state.pausedSeconds + pausedFor,
    );
    if (state.isRunning) _startTimer();
  }

  /// Marks the current local session complete. Persistence and task
  /// completion are orchestrated by the Focus presentation boundary.
  void complete() {
    if (!state.hasTask || state.isCompleted) return;
    _stopTimer();
    state = state.copyWith(
      remainingSeconds: 0,
      status: FocusSessionStatus.completed,
      clearPausedAt: true,
    );
  }

  void continueForFiveMinutes({DateTime? now}) {
    if (!state.isCompleted) return;
    final resumed = now ?? DateTime.now();
    state = state.copyWith(
      startAt: resumed,
      endAt: resumed.add(const Duration(minutes: 5)),
      remainingSeconds: 5 * 60,
      status: FocusSessionStatus.running,
      clearPausedAt: true,
    );
    _startTimer();
  }

  void tick([DateTime? now]) {
    if (!state.isRunning || state.endAt == null) return;
    final current = now ?? DateTime.now();
    final remaining = state.endAt!.difference(current).inMilliseconds;
    if (remaining <= 0) {
      _stopTimer();
      state = state.copyWith(
          remainingSeconds: 0, status: FocusSessionStatus.completed);
      return;
    }
    state = state.copyWith(remainingSeconds: (remaining / 1000).ceil());
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => tick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String _newSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
