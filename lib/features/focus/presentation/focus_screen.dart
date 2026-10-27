import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/dayweave_theme.dart';
import '../../../features/auth/application/current_user_provider.dart';
import '../../../models/task.dart';
import '../../../services/providers.dart';
import '../application/focus_session_controller.dart';
import '../../today/application/today_controller.dart';
import '../../today/application/today_focus_summary_controller.dart';

/// Static visual states for the Focus UI review. They intentionally do not
/// represent timer or session state yet.
enum FocusVisualState { ready, scheduled, running, paused, completed, empty }

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({
    this.task,
    this.visualState = FocusVisualState.running,
    this.showExitConfirmation = false,
    super.key,
  });

  final Task? task;
  final FocusVisualState visualState;
  final bool showExitConfirmation;

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  late bool _showExitConfirmation;
  bool _completionInFlight = false;
  String? _completionError;

  @override
  void initState() {
    super.initState();
    _showExitConfirmation = widget.showExitConfirmation;
    Future<void>.microtask(() {
      if (mounted) {
        ref.read(focusSessionProvider.notifier).start(widget.task);
      }
    });
  }

  Future<bool> _handleSystemBack() async {
    if (_showExitConfirmation) {
      setState(() => _showExitConfirmation = false);
    } else {
      setState(() => _showExitConfirmation = true);
    }
    return false;
  }

  void _requestExit() => setState(() => _showExitConfirmation = true);

  void _leaveFocus() {
    ref.read(focusSessionProvider.notifier).pause();
    Navigator.of(context).pop();
  }

  Future<void> _completeFocus() async {
    if (_completionInFlight) return;
    final session = ref.read(focusSessionProvider);
    final task = session.task;
    final userId = ref.read(currentUserIdProvider);
    if (task == null || session.sessionId == null || userId == null) {
      debugPrint(
          'Focus completion unavailable: missing session or user context.');
      setState(() =>
          _completionError = 'Focus could not be completed. Please try again.');
      return;
    }

    setState(() {
      _completionInFlight = true;
      _completionError = null;
    });
    ref.read(focusSessionProvider.notifier).complete();
    final completedAt = DateTime.now().toUtc();
    var failedStage = 'persistence';
    try {
      await ref.read(focusRepositoryProvider).saveCompleted(userId, {
        'session_id': session.sessionId,
        'task_id': task.id,
        'task_title': task.title,
        'task_date': task.date,
        'planned_duration_seconds': session.plannedDurationSeconds,
        'started_at':
            (session.startAt ?? completedAt).toUtc().toIso8601String(),
        'completed_at': completedAt.toIso8601String(),
        'paused_seconds': session.pausedSeconds,
      });
      failedStage = 'task completion';
      final taskCompleted = await ref
          .read(todayControllerProvider.notifier)
          .completeTask(task.id);
      if (!taskCompleted) {
        throw StateError('Task completion was not confirmed.');
      }
      try {
        await ref.read(todayFocusSummaryProvider.notifier).load();
      } catch (_) {
        // The completed task/session are already persisted. Summary refresh
        // can be retried from Today without reporting a false completion error.
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint(
          'Focus completion failed during $failedStage: ${error.runtimeType}: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _completionError = 'Focus could not be completed. Please try again.';
          _completionInFlight = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _completionInFlight = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(focusSessionProvider);
    final hasTask = session.hasTask;
    final isCompleted = session.isCompleted;
    final isPaused = session.isPaused;
    return WillPopScope(
      onWillPop: _handleSystemBack,
      child: Scaffold(
        backgroundColor: _FocusColors.ink,
        body: SafeArea(
          child: Stack(fit: StackFit.expand, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DayweaveSpacing.lg,
                  DayweaveSpacing.md, DayweaveSpacing.lg, DayweaveSpacing.lg),
              child: hasTask
                  ? _FocusTaskView(
                      task: session.task!,
                      remainingSeconds: session.remainingSeconds,
                      plannedDurationSeconds: session.plannedDurationSeconds,
                      isCompleted: isCompleted,
                      isPaused: isPaused,
                      onPause: () =>
                          ref.read(focusSessionProvider.notifier).pause(),
                      onResume: () =>
                          ref.read(focusSessionProvider.notifier).resume(),
                      onComplete: () => _completeFocus(),
                      completing: _completionInFlight,
                      completionError: _completionError,
                      onContinue: () => ref
                          .read(focusSessionProvider.notifier)
                          .continueForFiveMinutes(),
                      onExit: _requestExit,
                    )
                  : const _FocusEmptyView(),
            ),
            if (_showExitConfirmation)
              _ExitConfirmation(
                onKeepFocusing: () =>
                    setState(() => _showExitConfirmation = false),
                onLeaveFocus: _leaveFocus,
              ),
          ]),
        ),
      ),
    );
  }
}

class _FocusTaskView extends StatelessWidget {
  const _FocusTaskView({
    required this.task,
    required this.remainingSeconds,
    required this.plannedDurationSeconds,
    required this.isCompleted,
    required this.isPaused,
    required this.onPause,
    required this.onResume,
    required this.onComplete,
    required this.onExit,
    required this.completing,
    required this.completionError,
    required this.onContinue,
  });

  final Task task;
  final int remainingSeconds;
  final int plannedDurationSeconds;
  final bool isCompleted;
  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onComplete;
  final VoidCallback onExit;
  final bool completing;
  final String? completionError;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Column(children: [
        _ResponsiveFocusHeader(onExit: onExit),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;
            final timerSize = compact ? 224.0 : 276.0;
            final titleSize = compact ? 38.0 : 42.0;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RouteContext(task: task),
                      SizedBox(
                          height: compact
                              ? DayweaveSpacing.md
                              : DayweaveSpacing.xl),
                      Text(task.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                                  color: _FocusColors.paper,
                                  fontSize: titleSize,
                                  height: .96)),
                      const SizedBox(height: DayweaveSpacing.md),
                      Text(task.note,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                  color: _FocusColors.muted, height: 1.45)),
                      SizedBox(height: compact ? DayweaveSpacing.lg : 34),
                      _TimerDial(
                          size: timerSize,
                          completed: isCompleted,
                          paused: isPaused,
                          remainingSeconds: remainingSeconds,
                          plannedDurationSeconds: plannedDurationSeconds),
                      SizedBox(
                          height: compact
                              ? DayweaveSpacing.md
                              : DayweaveSpacing.lg),
                      if (isCompleted)
                        _CompletedFocusCopy(
                            onComplete: onComplete,
                            onContinue: onContinue,
                            completing: completing,
                            error: completionError)
                      else
                        _FocusControls(
                            paused: isPaused,
                            plannedDurationSeconds: plannedDurationSeconds,
                            onPause: onPause,
                            onResume: onResume,
                            onComplete: onComplete,
                            completing: completing,
                            error: completionError),
                    ]),
              ),
            );
          }),
        ),
      ]);
}

class _ResponsiveFocusHeader extends StatelessWidget {
  const _ResponsiveFocusHeader({required this.onExit});
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: constraints.maxWidth,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/dayweave-mark.webp',
                          width: 38, height: 38),
                      const SizedBox(width: DayweaveSpacing.sm),
                      Text('dayweave',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                  color: _FocusColors.paper, fontSize: 24)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: DayweaveSpacing.sm),
              OutlinedButton.icon(
                onPressed: onExit,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Exit'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: _FocusColors.muted,
                    side: const BorderSide(color: _FocusColors.line),
                    minimumSize: const Size(0, 50),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
              ),
            ],
          ),
        ),
      );
}

// ignore: unused_element
class _FocusHeader extends StatelessWidget {
  const _FocusHeader();

  @override
  Widget build(BuildContext context) => Row(children: [
        Image.asset('assets/images/dayweave-mark.webp', width: 30, height: 30),
        const SizedBox(width: DayweaveSpacing.sm),
        Text('dayweave',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: _FocusColors.paper, fontSize: 22)),
        const Spacer(),
        Text('ONE THING · 5:30 PM',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: _FocusColors.muted, letterSpacing: 1.1)),
        const SizedBox(width: DayweaveSpacing.sm),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Exit'),
          style: OutlinedButton.styleFrom(
              foregroundColor: _FocusColors.muted,
              side: const BorderSide(color: _FocusColors.line),
              minimumSize: const Size(44, 44)),
        ),
      ]);
}

class _RouteContext extends StatelessWidget {
  const _RouteContext({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const _ContextLine(),
        const SizedBox(width: DayweaveSpacing.sm),
        Text('AFTERNOON · DEEP ENERGY',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: _FocusColors.marigold, letterSpacing: 1.6)),
        const SizedBox(width: DayweaveSpacing.sm),
        const _ContextLine(),
      ]);
}

class _ContextLine extends StatelessWidget {
  const _ContextLine();
  @override
  Widget build(BuildContext context) => const SizedBox(
      width: 28, child: Divider(color: _FocusColors.line, height: 1));
}

class _TimerDial extends StatelessWidget {
  const _TimerDial(
      {required this.size,
      required this.completed,
      required this.paused,
      required this.remainingSeconds,
      required this.plannedDurationSeconds});
  final double size;
  final bool completed;
  final bool paused;
  final int remainingSeconds;
  final int plannedDurationSeconds;

  @override
  Widget build(BuildContext context) {
    final caption = completed
        ? 'TIME WELL SPENT'
        : paused
            ? 'PAUSED'
            : 'FOCUSING';
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    final progress = plannedDurationSeconds == 0
        ? 0.0
        : (1 - remainingSeconds / plannedDurationSeconds).clamp(0.0, 1.0);
    return Semantics(
      label: completed
          ? 'Focus block complete'
          : '$minutes minutes and $seconds seconds remaining, $caption',
      child: SizedBox(
        height: size,
        width: size,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(
            size: Size.square(size),
            painter: _FocusTimerPainter(progress: completed ? 1 : progress),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(completed ? 'Done' : '$minutes:$seconds',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: _FocusColors.paper,
                    fontSize: size < 240 ? 48 : 58,
                    height: 1)),
            const SizedBox(height: DayweaveSpacing.sm),
            Text(caption,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: _FocusColors.muted, letterSpacing: 1.45)),
          ]),
        ]),
      ),
    );
  }
}

class _FocusTimerPainter extends CustomPainter {
  const _FocusTimerPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 9;
    final bounds = Rect.fromCircle(center: center, radius: radius);

    final base = Paint()
      ..color = _FocusColors.ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, base);

    final accent = Paint()
      ..color = _FocusColors.marigold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(bounds, -math.pi / 2, math.pi * 2 * progress, false, accent);
  }

  @override
  bool shouldRepaint(covariant _FocusTimerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _FocusControls extends StatelessWidget {
  const _FocusControls(
      {required this.paused,
      required this.plannedDurationSeconds,
      required this.onPause,
      required this.onResume,
      required this.onComplete,
      required this.completing,
      required this.error});
  final bool paused;
  final int plannedDurationSeconds;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onComplete;
  final bool completing;
  final String? error;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final groupWidth = math.min(constraints.maxWidth, 300.0);
          return SizedBox(
            width: groupWidth,
            child: Column(children: [
              if (error != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: DayweaveSpacing.sm),
                    child: Text(error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _FocusColors.error))),
              Text('48% complete · 30 min planned',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _FocusColors.muted)),
              const SizedBox(height: DayweaveSpacing.md),
              if (constraints.maxWidth >= 300)
                Row(
                  children: [
                    SizedBox(
                      width: (groupWidth - DayweaveSpacing.sm) / 2,
                      child: OutlinedButton(
                        onPressed: paused ? onResume : onPause,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: _FocusColors.paper,
                            side: const BorderSide(color: _FocusColors.line),
                            minimumSize: const Size(0, 54),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(fontSize: 16)),
                        child: Text(paused ? 'Resume' : 'Pause'),
                      ),
                    ),
                    SizedBox(
                      width: (groupWidth - DayweaveSpacing.sm) / 2,
                      child: FilledButton.icon(
                        onPressed: completing ? null : onComplete,
                        style: FilledButton.styleFrom(
                            backgroundColor: _FocusColors.marigold,
                            foregroundColor: _FocusColors.ink,
                            minimumSize: const Size(0, 54),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        icon: const Icon(Icons.check, size: 17),
                        label: const Text('Complete'),
                      ),
                    ),
                  ],
                )
              else
                Column(children: [
                  SizedBox(
                    width: constraints.maxWidth,
                    child: OutlinedButton(
                      onPressed: paused ? onResume : onPause,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _FocusColors.paper,
                        side: const BorderSide(color: _FocusColors.line),
                        minimumSize: const Size(0, 54),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      child: Text(paused ? 'Resume' : 'Pause'),
                    ),
                  ),
                  const SizedBox(height: DayweaveSpacing.sm),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: FilledButton.icon(
                      onPressed: completing ? null : onComplete,
                      style: FilledButton.styleFrom(
                        backgroundColor: _FocusColors.marigold,
                        foregroundColor: _FocusColors.ink,
                        minimumSize: const Size(0, 54),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      icon: const Icon(Icons.check, size: 17),
                      label: const Text('Complete'),
                    ),
                  ),
                ]),
            ]),
          );
        },
      );
}

class _CompletedFocusCopy extends StatelessWidget {
  const _CompletedFocusCopy({
    required this.onComplete,
    required this.onContinue,
    required this.completing,
    this.error,
  });
  final VoidCallback onComplete;
  final VoidCallback onContinue;
  final bool completing;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text('BLOCK COMPLETE',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: _FocusColors.marigold, letterSpacing: 1.5)),
        const SizedBox(height: DayweaveSpacing.sm),
        Text('You stayed with it.',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: _FocusColors.paper, fontSize: 28)),
        const SizedBox(height: DayweaveSpacing.xs),
        Text('The task is still here until you choose what comes next.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: _FocusColors.muted)),
        const SizedBox(height: DayweaveSpacing.md),
        if (error != null)
          Padding(
              padding: const EdgeInsets.only(bottom: DayweaveSpacing.sm),
              child: Text(error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _FocusColors.error))),
        FilledButton.icon(
          onPressed: completing ? null : onComplete,
          style: FilledButton.styleFrom(
              backgroundColor: _FocusColors.marigold,
              foregroundColor: _FocusColors.ink,
              minimumSize: const Size(180, 48)),
          icon: const Icon(Icons.check, size: 17),
          label: const Text('Mark complete'),
        ),
        TextButton(
            onPressed: completing ? null : onContinue,
            child: const Text('Continue for 5 more minutes')),
      ]);
}

class _FocusEmptyView extends StatelessWidget {
  const _FocusEmptyView();

  @override
  Widget build(BuildContext context) => Column(children: [
        _ResponsiveFocusHeader(onExit: () {}),
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                height: 76,
                width: 76,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                        BorderSide(color: _FocusColors.line))),
                child: const Icon(Icons.eco_outlined,
                    color: _FocusColors.marigold, size: 32),
              ),
              const SizedBox(height: DayweaveSpacing.xl),
              Text('A QUIET START',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _FocusColors.marigold, letterSpacing: 1.5)),
              const SizedBox(height: DayweaveSpacing.md),
              Text('Nothing needs your\nattention yet.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: _FocusColors.paper, fontSize: 38, height: .98)),
              const SizedBox(height: DayweaveSpacing.md),
              Text(
                  'Give the day one clear thing first, then come back here when it is ready for your attention.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: _FocusColors.muted)),
              const SizedBox(height: DayweaveSpacing.xl),
              FilledButton.icon(
                onPressed: () {},
                style: FilledButton.styleFrom(
                    backgroundColor: _FocusColors.marigold,
                    foregroundColor: _FocusColors.ink,
                    minimumSize: const Size(180, 48)),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Add a task'),
              ),
              TextButton(
                  onPressed: () {}, child: const Text('Return to Today')),
            ]),
          ),
        ),
      ]);
}

class _ExitConfirmation extends StatelessWidget {
  const _ExitConfirmation({
    required this.onKeepFocusing,
    required this.onLeaveFocus,
  });
  final VoidCallback onKeepFocusing;
  final VoidCallback onLeaveFocus;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: ColoredBox(
            color: const Color(0xD914252A),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(DayweaveSpacing.xl),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('KEEP THE THREAD',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _FocusColors.marigold, letterSpacing: 1.5)),
                  const SizedBox(height: DayweaveSpacing.md),
                  Text('Leave focus?',
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(color: _FocusColors.paper, fontSize: 36)),
                  const SizedBox(height: DayweaveSpacing.sm),
                  Text('Your progress will be kept.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: _FocusColors.muted)),
                  const SizedBox(height: DayweaveSpacing.lg),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    OutlinedButton(
                        onPressed: onKeepFocusing,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: _FocusColors.paper,
                            side: const BorderSide(color: _FocusColors.line),
                            minimumSize: const Size(0, 48)),
                        child: const Text('Keep focusing')),
                    const SizedBox(width: DayweaveSpacing.sm),
                    FilledButton(
                        onPressed: onLeaveFocus,
                        style: FilledButton.styleFrom(
                            foregroundColor: _FocusColors.ink,
                            backgroundColor: _FocusColors.marigold,
                            minimumSize: const Size(0, 48)),
                        child: const Text('Leave focus')),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      );
}

abstract final class _FocusColors {
  static const ink = Color(0xFF1D3036);
  static const paper = Color(0xFFF7F3E8);
  static const muted = Color(0xFFB9C9C0);
  static const marigold = Color(0xFFD5AA43);
  static const ring = Color(0xFF3D5456);
  static const line = Color(0xFF50656A);
  static const error = Color(0xFFF0B6A8);
}
