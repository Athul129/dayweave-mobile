import 'package:flutter/material.dart';

import '../../../core/theme/dayweave_theme.dart';

class FocusHistoryScreen extends StatelessWidget {
  const FocusHistoryScreen({super.key});

  // Static presentation state until history data is connected.
  static const previewState = _HistoryPreviewState.populated;

  @override
  Widget build(BuildContext context) {
    final content = switch (previewState) {
      _HistoryPreviewState.populated => _populated(context),
      _HistoryPreviewState.empty => _empty(context),
      _HistoryPreviewState.loading => _loading(context),
      _HistoryPreviewState.error => _error(context),
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DayweaveSpacing.lg,
          8,
          DayweaveSpacing.lg,
          28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hero(context),
            const SizedBox(height: 16),
            _rangeSelector(context),
            const SizedBox(height: 14),
            content,
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        decoration: const BoxDecoration(
          color: DayweaveColors.bluePaper,
          borderRadius: DayweaveRadii.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow(context, 'FOCUS HISTORY'),
            const SizedBox(height: 12),
            Text(
              'Focus History',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontFamily: 'Fraunces',
                    fontWeight: FontWeight.w600,
                    fontSize: 34,
                    height: .98,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              "A record of the focus sessions you've completed.",
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.45),
            ),
          ],
        ),
      );

  Widget _rangeSelector(BuildContext context) => Row(
        children: [
          Text(
            'Show',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: DayweaveColors.ink),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.expand_more, size: 18),
            label: const Text('All time'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(124, 46),
              foregroundColor: DayweaveColors.ink,
              side: const BorderSide(color: DayweaveColors.line),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      );

  Widget _populated(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metrics(context),
          const SizedBox(height: 28),
          _daySection(context, 'TODAY', [
            const _Session(
              'Finish API integration',
              'Completed at 4:32 PM',
              '30 min',
              'Paused 5 min',
            ),
            const _Session(
              'Review authentication',
              'Completed at 2:15 PM',
              '25 min',
              null,
            ),
          ]),
          const SizedBox(height: 24),
          _daySection(context, 'YESTERDAY', [
            const _Session(
              'Plan database changes',
              'Completed at 5:10 PM',
              '45 min',
              'Paused 3 min',
            ),
          ]),
        ],
      );

  Widget _metrics(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 6),
        decoration: BoxDecoration(
          color: DayweaveColors.card,
          border: Border.all(color: DayweaveColors.line),
          borderRadius: DayweaveRadii.md,
        ),
        child: Row(
          children: [
            _metric(context, Icons.check_circle_outline, '8', 'COMPLETED'),
            _metric(context, Icons.schedule_outlined, '3h 20m', 'FOCUSED'),
            _metric(context, Icons.pause_circle_outline, '12m', 'PAUSED'),
          ],
        ),
      );

  Widget _metric(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) =>
      Expanded(
        child: Container(
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              right: label == 'PAUSED'
                  ? BorderSide.none
                  : const BorderSide(color: DayweaveColors.line),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 25, color: DayweaveColors.inkSoft),
              const SizedBox(height: 5),
              Text(
                value,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'Fraunces',
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: DayweaveColors.inkSoft, letterSpacing: 1),
              ),
            ],
          ),
        ),
      );

  Widget _daySection(
    BuildContext context,
    String label,
    List<_Session> sessions,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: DayweaveColors.inkSoft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
          ),
          const SizedBox(height: 9),
          ...sessions.map(
            (session) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _sessionRow(context, session),
            ),
          ),
        ],
      );

  Widget _sessionRow(BuildContext context, _Session session) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
        decoration: BoxDecoration(
          color: DayweaveColors.card,
          border: Border.all(color: DayweaveColors.line),
          borderRadius: DayweaveRadii.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: 'Fraunces',
                          fontSize: 18,
                          height: 1.1,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    session.completedAt,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: DayweaveColors.inkSoft),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    children: [
                      _pill(
                        context,
                        Icons.schedule_outlined,
                        session.duration,
                        DayweaveColors.sage.withValues(alpha: .55),
                      ),
                      if (session.paused != null)
                        _pill(
                          context,
                          Icons.pause_circle_outline,
                          session.paused!,
                          const Color(0xFFF5E7CB),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: DayweaveColors.inkSoft),
          ],
        ),
      );

  Widget _pill(BuildContext context, IconData icon, String text, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: DayweaveColors.inkSoft),
            const SizedBox(width: 4),
            Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: DayweaveColors.inkSoft),
            ),
          ],
        ),
      );

  Widget _empty(BuildContext context) => _stateCard(
        context,
        Icons.timer_outlined,
        'No focus sessions yet',
        'Complete a focus session to see it here.',
        'Go to Focus',
      );

  Widget _loading(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: DayweaveColors.card,
          border: Border.all(color: DayweaveColors.line),
          borderRadius: DayweaveRadii.md,
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(
              strokeWidth: 2,
              color: DayweaveColors.marigold,
            ),
            const SizedBox(height: 14),
            Text(
              'Loading Focus History…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );

  Widget _error(BuildContext context) => _stateCard(
        context,
        Icons.error_outline,
        'Something went wrong',
        "We couldn't load your focus history.\nPlease try again.",
        'Try again',
        destructive: true,
      );

  Widget _stateCard(
    BuildContext context,
    IconData icon,
    String title,
    String message,
    String action, {
    bool destructive = false,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
        decoration: BoxDecoration(
          color: DayweaveColors.card,
          border: Border.all(color: DayweaveColors.line),
          borderRadius: DayweaveRadii.md,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 30,
              color:
                  destructive ? DayweaveColors.coral : DayweaveColors.inkSoft,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () {},
              icon: Icon(
                destructive ? Icons.refresh : Icons.play_arrow_outlined,
                size: 17,
              ),
              label: Text(action),
              style: OutlinedButton.styleFrom(
                foregroundColor: destructive
                    ? DayweaveColors.coral
                    : DayweaveColors.marigold,
                side: BorderSide(
                  color: destructive
                      ? DayweaveColors.coral
                      : DayweaveColors.marigold,
                ),
                minimumSize: const Size(0, 44),
              ),
            ),
          ],
        ),
      );

  Widget _eyebrow(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: DayweaveColors.inkSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.7,
            ),
      );
}

enum _HistoryPreviewState { populated, empty, loading, error }

class _Session {
  const _Session(this.title, this.completedAt, this.duration, this.paused);
  final String title;
  final String completedAt;
  final String duration;
  final String? paused;
}
