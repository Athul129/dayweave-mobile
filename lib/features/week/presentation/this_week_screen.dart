import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/dayweave_theme.dart';

class ThisWeekScreen extends StatelessWidget {
  const ThisWeekScreen({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              DayweaveSpacing.lg, 8, DayweaveSpacing.lg, 28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _WeekIntro(),
            const SizedBox(height: 20),
            const _WeekSummary(),
            const SizedBox(height: 18),
            const _WeekNavigation(),
            const SizedBox(height: 12),
            const _DaySelector(),
            const SizedBox(height: 20),
            _SelectedDay(),
            const SizedBox(height: 24),
            const _BreathingNote(),
          ]),
        ),
      );
}

class _WeekIntro extends StatelessWidget {
  const _WeekIntro();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        decoration: const BoxDecoration(
          color: DayweaveColors.bluePaper,
          borderRadius: DayweaveRadii.lg,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WEEKLY FIELD NOTES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: DayweaveColors.inkSoft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8)),
          const SizedBox(height: 12),
          Text('Make a week\nthat can breathe.',
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(fontSize: 34, height: .98)),
          const SizedBox(height: 12),
          Text(
              'See the shape of what’s ahead without filling every inch of it.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: DayweaveColors.inkSoft, height: 1.45)),
        ]),
      );
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: DayweaveColors.card, borderRadius: DayweaveRadii.lg),
        child: Row(children: [
          SizedBox(
              width: 108,
              height: 108,
              child: Stack(alignment: Alignment.center, children: [
                const CustomPaint(
                  size: Size.square(108),
                  painter: _WeekProgressPainter(),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('67%',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700, height: 1)),
                  const SizedBox(height: 2),
                  Text('clear',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: DayweaveColors.inkSoft, height: 1)),
                ]),
              ])),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('WEEK IN VIEW',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: DayweaveColors.inkSoft,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4)),
                const SizedBox(height: 6),
                Text('2 of 5 tasks complete',
                    style: Theme.of(context).textTheme.bodyLarge),
                Text('90m planned across the week',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: DayweaveColors.inkSoft)),
              ])),
        ]),
      );
}

class _WeekProgressPainter extends CustomPainter {
  const _WeekProgressPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 7;
    final bounds = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = DayweaveColors.sage
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final progress = Paint()
      ..color = DayweaveColors.marigold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(bounds, 0, math.pi * 2, false, track);
    canvas.drawArc(bounds, -math.pi / 2, math.pi * 2 * .67, false, progress);
  }

  @override
  bool shouldRepaint(covariant _WeekProgressPainter oldDelegate) => false;
}

class _WeekNavigation extends StatelessWidget {
  const _WeekNavigation();
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.chevron_left),
                label: const Text('OCT 1 — 7, 2026'))),
        const SizedBox(width: DayweaveSpacing.sm),
        OutlinedButton(onPressed: () {}, child: const Text('Today')),
        const SizedBox(width: 2),
        IconButton(
            onPressed: () {},
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next week'),
      ]);
}

class _DaySelector extends StatelessWidget {
  const _DaySelector();
  @override
  Widget build(BuildContext context) => Row(
        children: const [
          _DayChip('MON', '1'),
          _DayChip('TUE', '2', selected: true),
          _DayChip('WED', '3'),
          _DayChip('THU', '4'),
          _DayChip('FRI', '5'),
          _DayChip('SAT', '6'),
          _DayChip('SUN', '7'),
        ].map((chip) => Expanded(child: chip)).toList(),
      );
}

class _DayChip extends StatelessWidget {
  const _DayChip(this.label, this.number, {this.selected = false});
  final String label;
  final String number;
  final bool selected;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
            color: selected
                ? DayweaveColors.marigold
                : DayweaveColors.sage.withValues(alpha: .35),
            borderRadius: DayweaveRadii.md),
        child: Column(children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontSize: 9, color: DayweaveColors.inkSoft)),
          const SizedBox(height: 3),
          Text(number,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );
}

class _SelectedDay extends StatelessWidget {
  _SelectedDay();
  final tasks = const [
    ('Finish API integration', '10:00 AM', 'Deep', '45m', false),
    ('Review documentation', '2:00 PM', 'Light', '30m', true),
  ];
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Tuesday, October 2',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontSize: 24)),
                const SizedBox(height: 6),
                Text('2 tasks · 1 done · 45m planned',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: DayweaveColors.inkSoft)),
              ])),
          FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Plan a task'),
              style: FilledButton.styleFrom(
                  backgroundColor: DayweaveColors.marigold,
                  foregroundColor: DayweaveColors.ink)),
        ]),
        const SizedBox(height: 16),
        ...tasks.map((task) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _WeekTaskRow(task: task))),
        const SizedBox(height: 14),
        Text('Thursday, October 4',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontSize: 21)),
        const SizedBox(height: 6),
        Text('No tasks yet. A little space is a good thing.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: DayweaveColors.inkSoft)),
        const SizedBox(height: 12),
        const _DropTarget(),
      ]);
}

class _WeekTaskRow extends StatelessWidget {
  const _WeekTaskRow({required this.task});
  final (String, String, String, String, bool) task;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: DayweaveColors.card,
            border: Border.all(color: DayweaveColors.line),
            borderRadius: DayweaveRadii.md),
        child: Row(children: [
          const Icon(Icons.drag_indicator,
              size: 20, color: DayweaveColors.inkSoft),
          Icon(task.$5 ? Icons.check_circle : Icons.circle_outlined,
              color: task.$5 ? Colors.green.shade600 : DayweaveColors.inkSoft),
          const SizedBox(width: 9),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(task.$1,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text('${task.$2} · ${task.$3}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: DayweaveColors.inkSoft)),
              ])),
          Text(task.$4,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: DayweaveColors.inkSoft)),
          const SizedBox(width: 5),
          const Icon(Icons.more_vert, size: 18, color: DayweaveColors.inkSoft),
        ]),
      );
}

class _DropTarget extends StatelessWidget {
  const _DropTarget();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 19),
        decoration: BoxDecoration(
            color: DayweaveColors.bluePaper.withValues(alpha: .45),
            border: Border.all(color: DayweaveColors.inkSoft, width: 1.3),
            borderRadius: DayweaveRadii.md),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.arrow_downward,
              color: DayweaveColors.inkSoft, size: 18),
          const SizedBox(width: 8),
          Text('Drop here to move this task',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: DayweaveColors.inkSoft)),
        ]),
      );
}

class _BreathingNote extends StatelessWidget {
  const _BreathingNote();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: DayweaveColors.bluePaper.withValues(alpha: .55),
            borderRadius: DayweaveRadii.lg),
        child: Text('Leave a little room between\nthe landmarks.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                color: DayweaveColors.inkSoft)),
      );
}
