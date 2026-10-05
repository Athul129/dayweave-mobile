import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/dayweave_theme.dart';

/// Static visual states for the Focus UI review. They intentionally do not
/// represent timer or session state yet.
enum FocusVisualState { ready, scheduled, running, paused, completed, empty }

class FocusScreen extends StatelessWidget {
  const FocusScreen({
    this.visualState = FocusVisualState.running,
    this.showExitConfirmation = false,
    super.key,
  });

  final FocusVisualState visualState;
  final bool showExitConfirmation;

  bool get _hasTask => visualState != FocusVisualState.empty;
  bool get _isCompleted => visualState == FocusVisualState.completed;
  bool get _isPaused => visualState == FocusVisualState.paused;
  bool get _isScheduled => visualState == FocusVisualState.scheduled;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _FocusColors.ink,
        body: SafeArea(
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  DayweaveSpacing.lg, DayweaveSpacing.md, DayweaveSpacing.lg, DayweaveSpacing.lg),
              child: _hasTask ? _FocusTaskView(
                  isCompleted: _isCompleted,
                  isPaused: _isPaused,
                  isScheduled: _isScheduled,
                ) : const _FocusEmptyView(),
            ),
            if (showExitConfirmation) const _ExitConfirmation(),
          ]),
        ),
      );
}

class _FocusTaskView extends StatelessWidget {
  const _FocusTaskView({
    required this.isCompleted,
    required this.isPaused,
    required this.isScheduled,
  });

  final bool isCompleted;
  final bool isPaused;
  final bool isScheduled;

  @override
  Widget build(BuildContext context) => Column(children: [
        const _ResponsiveFocusHeader(),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;
            final timerSize = compact ? 224.0 : 276.0;
            final titleSize = compact ? 38.0 : 42.0;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const _RouteContext(),
                SizedBox(height: compact ? DayweaveSpacing.md : DayweaveSpacing.xl),
                Text('Finish the API\nintegration',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: _FocusColors.paper, fontSize: titleSize, height: .96)),
                const SizedBox(height: DayweaveSpacing.md),
                Text('Connect the remaining endpoints and verify the response flow.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: _FocusColors.muted, height: 1.45)),
                SizedBox(height: compact ? DayweaveSpacing.lg : 34),
                _TimerDial(size: timerSize, completed: isCompleted, paused: isPaused, scheduled: isScheduled),
                SizedBox(height: compact ? DayweaveSpacing.md : DayweaveSpacing.lg),
                if (isCompleted)
                  const _CompletedFocusCopy()
                else
                  _FocusControls(paused: isPaused, scheduled: isScheduled),
                ]),
              ),
            );
          }),
        ),
      ]);
}

class _ResponsiveFocusHeader extends StatelessWidget {
  const _ResponsiveFocusHeader();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, _) => Row(children: [
          Expanded(
            child: Row(children: [
              Image.asset('assets/images/dayweave-mark.webp', width: 38, height: 38),
              const SizedBox(width: DayweaveSpacing.sm),
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text('dayweave',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: _FocusColors.paper, fontSize: 24)),
                ),
              ),
            ]),
          ),
          const SizedBox(width: DayweaveSpacing.sm),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () {},
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
        ]),
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _FocusColors.paper, fontSize: 22)),
        const Spacer(),
        Text('ONE THING · 5:30 PM',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _FocusColors.muted, letterSpacing: 1.1)),
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
  const _RouteContext();

  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const _ContextLine(),
        const SizedBox(width: DayweaveSpacing.sm),
        Text('AFTERNOON · DEEP ENERGY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _FocusColors.marigold, letterSpacing: 1.6)),
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
  const _TimerDial({required this.size, required this.completed, required this.paused, required this.scheduled});
  final double size;
  final bool completed;
  final bool paused;
  final bool scheduled;

  @override
  Widget build(BuildContext context) {
    final caption = completed ? 'TIME WELL SPENT' : paused ? 'PAUSED' : scheduled ? 'NOT STARTED' : 'FOCUSING';
    return Semantics(
      label: completed ? 'Focus block complete' : '24 minutes and 32 seconds remaining, $caption',
      child: SizedBox(
        height: size,
        width: size,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(
            size: Size.square(size),
            painter: _FocusTimerPainter(progress: completed ? 1 : .48),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(completed ? 'Done' : '24:32',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: _FocusColors.paper, fontSize: size < 240 ? 48 : 58, height: 1)),
            const SizedBox(height: DayweaveSpacing.sm),
            Text(caption,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _FocusColors.muted, letterSpacing: 1.45)),
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
  bool shouldRepaint(covariant _FocusTimerPainter oldDelegate) => oldDelegate.progress != progress;
}

class _FocusControls extends StatelessWidget {
  const _FocusControls({required this.paused, required this.scheduled});
  final bool paused;
  final bool scheduled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final groupWidth = math.min(constraints.maxWidth, 300.0);
          return SizedBox(
          width: groupWidth,
          child: Column(children: [
          Text('48% complete · 30 min planned',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _FocusColors.muted)),
          const SizedBox(height: DayweaveSpacing.md),
          if (constraints.maxWidth >= 300)
            Row(
              children: [
              SizedBox(
                width: (groupWidth - DayweaveSpacing.sm) / 2,
                child: OutlinedButton(
                onPressed: () {},
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
                onPressed: () {},
                style: FilledButton.styleFrom(
                    backgroundColor: _FocusColors.marigold,
                    foregroundColor: _FocusColors.ink,
                    minimumSize: const Size(0, 54),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                  onPressed: () {},
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
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: _FocusColors.marigold,
                    foregroundColor: _FocusColors.ink,
                    minimumSize: const Size(0, 54),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
  const _CompletedFocusCopy();

  @override
  Widget build(BuildContext context) => Column(children: [
        Text('BLOCK COMPLETE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _FocusColors.marigold, letterSpacing: 1.5)),
        const SizedBox(height: DayweaveSpacing.sm),
        Text('You stayed with it.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _FocusColors.paper, fontSize: 28)),
        const SizedBox(height: DayweaveSpacing.xs),
        Text('The task is still here until you choose what comes next.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _FocusColors.muted)),
        const SizedBox(height: DayweaveSpacing.md),
        FilledButton.icon(
          onPressed: () {},
          style: FilledButton.styleFrom(
              backgroundColor: _FocusColors.marigold,
              foregroundColor: _FocusColors.ink,
              minimumSize: const Size(180, 48)),
          icon: const Icon(Icons.check, size: 17),
          label: const Text('Mark complete'),
        ),
        TextButton(onPressed: () {}, child: const Text('Continue for 5 more minutes')),
      ]);
}

class _FocusEmptyView extends StatelessWidget {
  const _FocusEmptyView();

  @override
  Widget build(BuildContext context) => Column(children: [
        const _ResponsiveFocusHeader(),
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                height: 76,
                width: 76,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: _FocusColors.line))),
                child: const Icon(Icons.eco_outlined, color: _FocusColors.marigold, size: 32),
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
              Text('Give the day one clear thing first, then come back here when it is ready for your attention.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: _FocusColors.muted)),
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
              TextButton(onPressed: () {}, child: const Text('Return to Today')),
            ]),
          ),
        ),
      ]);
}

class _ExitConfirmation extends StatelessWidget {
  const _ExitConfirmation();

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
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: _FocusColors.paper, fontSize: 36)),
                const SizedBox(height: DayweaveSpacing.sm),
                Text('Your progress will be kept.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: _FocusColors.muted)),
                const SizedBox(height: DayweaveSpacing.lg),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  OutlinedButton(onPressed: () {}, child: const Text('Keep focusing')),
                  const SizedBox(width: DayweaveSpacing.sm),
                  FilledButton(onPressed: () {}, child: const Text('Leave focus')),
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
}
