import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/application/current_user_provider.dart';
import '../../../models/domain_models.dart';
import '../../../core/theme/dayweave_theme.dart';
import '../application/focus_history_controller.dart';

class FocusHistoryScreen extends ConsumerStatefulWidget {
  const FocusHistoryScreen({super.key});

  @override
  ConsumerState<FocusHistoryScreen> createState() => _FocusHistoryScreenState();
}

class _FocusHistoryScreenState extends ConsumerState<FocusHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) ref.read(focusHistoryProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(currentUserIdProvider, (previous, next) {
      if (previous != next) {
        unawaited(ref.read(focusHistoryProvider.notifier).load());
      }
    });
    final history = ref.watch(focusHistoryProvider);
    final content = history.isLoading
        ? _loading(context)
        : history.error != null
            ? _error(
                context, () => ref.read(focusHistoryProvider.notifier).load())
            : history.filteredSessions.isEmpty
                ? _empty(context)
                : _populated(context, history);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(focusHistoryProvider.notifier).load(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
              _rangeSelector(context, history),
              const SizedBox(height: 14),
              content,
            ],
          ),
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

  Widget _rangeSelector(BuildContext context, FocusHistoryState history) => Row(
        children: [
          Text(
            'Show',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: DayweaveColors.ink),
          ),
          const Spacer(),
          Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: DayweaveColors.card,
              border: Border.all(color: DayweaveColors.line),
              borderRadius: BorderRadius.circular(28),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<FocusHistoryPeriod>(
                value: history.period,
                icon: const Icon(Icons.expand_more, size: 18),
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: DayweaveColors.ink),
                onChanged: (period) {
                  if (period != null) {
                    ref
                        .read(focusHistoryProvider.notifier)
                        .selectPeriod(period);
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: FocusHistoryPeriod.allTime,
                    child: Text('All time'),
                  ),
                  DropdownMenuItem(
                    value: FocusHistoryPeriod.thisWeek,
                    child: Text('This week'),
                  ),
                  DropdownMenuItem(
                    value: FocusHistoryPeriod.thisMonth,
                    child: Text('This month'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _populated(BuildContext context, FocusHistoryState history) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metrics(context, history),
          const SizedBox(height: 28),
          ...history.dayGroups.indexed.expand(
            (entry) => [
              if (entry.$1 > 0) const SizedBox(height: 24),
              _daySection(
                context,
                history.groupLabel(entry.$2.date),
                entry.$2.sessions,
              ),
            ],
          ),
        ],
      );

  Widget _metrics(BuildContext context, FocusHistoryState history) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 6),
        decoration: BoxDecoration(
          color: DayweaveColors.card,
          border: Border.all(color: DayweaveColors.line),
          borderRadius: DayweaveRadii.md,
        ),
        child: Row(
          children: [
            _metric(
              context,
              Icons.check_circle_outline,
              '${history.completedCount}',
              'COMPLETED',
            ),
            _metric(
              context,
              Icons.schedule_outlined,
              formatFocusDuration(history.plannedSeconds),
              'FOCUSED',
            ),
            _metric(
              context,
              Icons.pause_circle_outline,
              formatFocusDuration(history.pausedSeconds),
              'PAUSED',
            ),
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
    List<FocusSession> sessions,
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

  Widget _sessionRow(BuildContext context, FocusSession session) => Container(
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
                    session.taskTitle,
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
                    'Completed at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(session.completedAt.value.toLocal()))}',
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
                        formatFocusDuration(session.plannedDurationSeconds),
                        DayweaveColors.sage.withValues(alpha: .55),
                      ),
                      if (session.pausedSeconds > 0)
                        _pill(
                          context,
                          Icons.pause_circle_outline,
                          'Paused ${formatFocusDuration(session.pausedSeconds)}',
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
        null,
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

  Widget _error(BuildContext context, VoidCallback onRetry) => _stateCard(
        context,
        Icons.error_outline,
        'Something went wrong',
        "We couldn't load your focus history.\nPlease try again.",
        'Try again',
        destructive: true,
        onAction: onRetry,
      );

  Widget _stateCard(
    BuildContext context,
    IconData icon,
    String title,
    String message,
    String? action, {
    bool destructive = false,
    VoidCallback? onAction,
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
            if (action != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onAction,
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
