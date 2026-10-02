import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_time/dayweave_date_time.dart';
import '../../../core/theme/dayweave_theme.dart';
import '../../../models/task.dart';
import '../application/today_controller.dart';
import '../application/today_intention_controller.dart';
import '../application/today_state.dart';
import 'widgets/today_task_card.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});
  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late final TextEditingController _intentionController;
  late final FocusNode _intentionFocusNode;
  @override
  void initState() {
    super.initState();
    _intentionController = TextEditingController();
    _intentionFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _intentionController.dispose();
    _intentionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todayControllerProvider);
    final intention = ref.watch(todayIntentionProvider);
    final selectors = TodaySelectors(state);
    if (!_intentionFocusNode.hasFocus &&
        _intentionController.text != intention.value) {
      _intentionController.value = TextEditingValue(
          text: intention.value,
          selection: TextSelection.collapsed(offset: intention.value.length));
    }
    return Scaffold(
      backgroundColor: DayweaveColors.paper,
      body: SafeArea(
          child: RefreshIndicator(
        onRefresh: ref.read(todayControllerProvider.notifier).load,
        child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _TodayHeader(date: state.date)),
              SliverToBoxAdapter(
                  child: _MorningCheckIn(
                      controller: _intentionController,
                      focusNode: _intentionFocusNode,
                      state: intention,
                      selectors: selectors,
                      onChanged:
                          ref.read(todayIntentionProvider.notifier).update)),
              if (state.isLoading)
                const SliverToBoxAdapter(child: _LoadingState())
              else if (state.error != null)
                SliverToBoxAdapter(
                    child: _ErrorState(
                        onRetry:
                            ref.read(todayControllerProvider.notifier).load))
              else ...[
                SliverToBoxAdapter(child: _RouteHeader(selectors: selectors)),
                if (selectors.todayTasks.isEmpty)
                  const SliverToBoxAdapter(child: _EmptyRouteState())
                else
                  ..._sectionSlivers(selectors),
                const SliverToBoxAdapter(child: _BreathingRoomFooter()),
                SliverToBoxAdapter(child: _UpNextCard(task: selectors.upNext)),
              ],
              const SliverToBoxAdapter(
                  child: SizedBox(height: DayweaveSpacing.xl)),
            ]),
      )),
    );
  }

  List<Widget> _sectionSlivers(TodaySelectors selectors) => [
        _sectionSliver(selectors, TaskSection.morning, 'Morning'),
        _sectionSliver(selectors, TaskSection.midday, 'Midday'),
        _sectionSliver(selectors, TaskSection.afternoon, 'Afternoon'),
      ];
  Widget _sectionSliver(
      TodaySelectors selectors, TaskSection section, String label) {
    final tasks = selectors.tasksFor(section);
    if (tasks.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
          DayweaveSpacing.lg, DayweaveSpacing.md, DayweaveSpacing.lg, 0),
      sliver: SliverToBoxAdapter(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_sectionIcon(section),
                size: 19, color: _sectionColor(section)),
            const SizedBox(width: DayweaveSpacing.sm),
            Text(label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          ]),
          Text('${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}',
              style: Theme.of(context).textTheme.bodyMedium),
        ]),
        const SizedBox(height: DayweaveSpacing.sm),
        ...tasks.map((task) => Padding(
              padding: const EdgeInsets.only(bottom: DayweaveSpacing.sm),
              child: TodayTaskCard(
                  task: task,
                  selected: task.id == selectors.state.activeTaskId,
                  onSelect: () => ref
                      .read(todayControllerProvider.notifier)
                      .selectTask(task.id),
                  onToggleComplete: () => _toggleTask(task)),
            )),
      ])),
    );
  }

  IconData _sectionIcon(TaskSection section) => switch (section) {
        TaskSection.morning => Icons.wb_sunny_outlined,
        TaskSection.midday => Icons.wb_sunny_outlined,
        TaskSection.afternoon => Icons.nights_stay_outlined,
      };

  Color _sectionColor(TaskSection section) => switch (section) {
        TaskSection.morning => DayweaveColors.marigold,
        TaskSection.midday => DayweaveColors.marigold,
        TaskSection.afternoon => DayweaveColors.inkSoft,
      };

  Future<void> _toggleTask(Task task) async {
    final controller = ref.read(todayControllerProvider.notifier);
    await (task.done
        ? controller.uncompleteTask(task.id)
        : controller.completeTask(task.id));
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.date});
  final LocalDate date;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(DayweaveSpacing.lg,
            DayweaveSpacing.sm, DayweaveSpacing.lg, DayweaveSpacing.md),
        child: Text(
            MaterialLocalizations.of(context)
                .formatFullDate(date.asLocalDateTime),
            style: Theme.of(context).textTheme.titleMedium),
      );
}

class _MorningCheckIn extends StatelessWidget {
  const _MorningCheckIn(
      {required this.controller,
      required this.focusNode,
      required this.state,
      required this.selectors,
      required this.onChanged});
  final TextEditingController controller;
  final FocusNode focusNode;
  final TodayIntentionState state;
  final TodaySelectors selectors;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DayweaveSpacing.lg),
      padding: const EdgeInsets.symmetric(
          horizontal: DayweaveSpacing.xl, vertical: DayweaveSpacing.lg),
      decoration: const BoxDecoration(
          color: DayweaveColors.bluePaper, borderRadius: DayweaveRadii.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionLabel(
            icon: Icons.auto_awesome_outlined, text: 'MORNING CHECK-IN'),
        const SizedBox(height: DayweaveSpacing.md),
        Text(state.value,
            style: text.displayMedium?.copyWith(fontSize: 34, height: 1.08)),
        const SizedBox(height: DayweaveSpacing.sm),
        Text(
            'A little direction goes a long way. What would make today feel well spent?',
            style: text.bodyLarge?.copyWith(fontSize: 16, height: 1.45)),
        const SizedBox(height: DayweaveSpacing.lg),
        Row(children: [
          const Icon(Icons.edit_outlined,
              size: 20, color: DayweaveColors.marigold),
          const SizedBox(width: DayweaveSpacing.sm),
          Expanded(
              child: TextSelectionTheme(
                  data: const TextSelectionThemeData(
                      cursorColor: DayweaveColors.marigold,
                      selectionHandleColor: DayweaveColors.marigold),
                  child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: !state.isLoading,
                      onChanged: onChanged,
                      minLines: 1,
                      maxLines: 2,
                      style: text.bodyLarge,
                      decoration: const InputDecoration(
                          isDense: true,
                          filled: false,
                          hintText: 'Set an intention for today',
                          contentPadding:
                              EdgeInsets.only(bottom: DayweaveSpacing.xs),
                          border: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: DayweaveColors.inkSoft)),
                          enabledBorder: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: DayweaveColors.marigold)),
                          focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: DayweaveColors.marigold,
                                  width: 1.5)))))),
        ]),
        if (state.isLoading || state.isSaving) ...[
          const SizedBox(height: DayweaveSpacing.sm),
          const LinearProgressIndicator(minHeight: 2)
        ],
        if (state.error != null) ...[
          const SizedBox(height: DayweaveSpacing.sm),
          Text('Your intention could not be saved. Please try again.',
              style: text.bodyMedium?.copyWith(color: DayweaveColors.coral))
        ],
        const SizedBox(height: DayweaveSpacing.lg),
        _ProgressSummary(selectors: selectors),
      ]),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.selectors});
  final TodaySelectors selectors;
  @override
  Widget build(BuildContext context) => Row(children: [
        Semantics(
            label:
                '${selectors.progress}% complete, ${selectors.completedCount} of ${selectors.totalCount} tasks',
            child: SizedBox(
                height: 84,
                width: 84,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(
                      height: 84,
                      width: 84,
                      child: CircularProgressIndicator(
                          value: selectors.progress / 100,
                          strokeWidth: 8,
                          backgroundColor: DayweaveColors.line,
                          color: DayweaveColors.marigold)),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${selectors.progress}%',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text('clear',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 11))
                  ]),
                ]))),
        const SizedBox(width: DayweaveSpacing.lg),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${selectors.completedCount} of ${selectors.totalCount} tasks',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: DayweaveSpacing.xs),
          Text(
              '${selectors.remainingMinutes} min left · ${selectors.totalPlannedMinutes} min planned',
              style: Theme.of(context).textTheme.bodyMedium),
        ])),
      ]);
}

class _RouteHeader extends StatelessWidget {
  const _RouteHeader({required this.selectors});
  final TodaySelectors selectors;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(DayweaveSpacing.lg,
            DayweaveSpacing.xxl, DayweaveSpacing.lg, DayweaveSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 2, width: 56, color: DayweaveColors.marigold),
          const SizedBox(height: DayweaveSpacing.lg),
          const _SectionLabel(text: 'YOUR ROUTE'),
          const SizedBox(height: DayweaveSpacing.sm),
          LayoutBuilder(builder: (context, constraints) {
            final remaining = Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.schedule_outlined,
                  size: 18, color: DayweaveColors.inkSoft),
              const SizedBox(width: DayweaveSpacing.xs),
              Text('${selectors.remainingMinutes}m left',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]);
            final heading = Text('Shape the day',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontSize: 30));
            if (constraints.maxWidth < 350) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: DayweaveSpacing.xs),
                    remaining
                  ]);
            }
            return Row(children: [Expanded(child: heading), remaining]);
          }),
        ]),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.icon});
  final String text;
  final IconData? icon;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: DayweaveColors.marigold),
          const SizedBox(width: DayweaveSpacing.sm)
        ],
        Text(text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: DayweaveColors.inkSoft,
                letterSpacing: 1.7,
                fontWeight: FontWeight.w700)),
      ]);
}

class _EmptyRouteState extends StatelessWidget {
  const _EmptyRouteState();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: DayweaveSpacing.lg),
        padding: const EdgeInsets.symmetric(
            horizontal: DayweaveSpacing.lg, vertical: DayweaveSpacing.lg),
        decoration: BoxDecoration(
            color: DayweaveColors.card,
            borderRadius: DayweaveRadii.md,
            border: Border.all(color: DayweaveColors.line)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircleAvatar(
              radius: 21,
              backgroundColor: DayweaveColors.paper,
              foregroundColor: DayweaveColors.marigold,
              child: Icon(Icons.add, size: 28)),
          const SizedBox(height: DayweaveSpacing.md),
          Text('Your route starts here.',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontSize: 26)),
          const SizedBox(height: DayweaveSpacing.sm),
          Text('When you are ready, give today one small thing to hold.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
        ]),
      );
}

class _BreathingRoomFooter extends StatelessWidget {
  const _BreathingRoomFooter();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(DayweaveSpacing.lg,
            DayweaveSpacing.xl, DayweaveSpacing.lg, DayweaveSpacing.xl),
        child: Row(children: [
          const Icon(Icons.air, color: DayweaveColors.inkSoft),
          const SizedBox(width: DayweaveSpacing.md),
          Expanded(
              child: Text('Leave 45 minutes unplanned',
                  style: Theme.of(context).textTheme.bodyLarge)),
          Text('Why?', style: Theme.of(context).textTheme.bodyMedium)
        ]),
      );
}

class _UpNextCard extends StatelessWidget {
  const _UpNextCard({required this.task});
  final Task? task;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: DayweaveSpacing.lg),
        padding: const EdgeInsets.all(DayweaveSpacing.lg),
        decoration: const BoxDecoration(
            color: DayweaveColors.sage, borderRadius: DayweaveRadii.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.circle, size: 12, color: DayweaveColors.marigold),
            SizedBox(width: DayweaveSpacing.sm),
            _SectionLabel(text: 'UP NEXT'),
            Spacer(),
            Icon(Icons.eco_outlined, color: DayweaveColors.inkSoft)
          ]),
          const SizedBox(height: DayweaveSpacing.lg),
          if (task == null) ...[
            Text('Nothing pressing.',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontSize: 27)),
            const SizedBox(height: DayweaveSpacing.sm),
            Text('You made it to the other side of the list.',
                style: Theme.of(context).textTheme.bodyLarge)
          ] else ...[
            Text('${task!.time} · ${task!.minutes} min · ${task!.energy.name}',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: DayweaveSpacing.sm),
            Text(task!.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontSize: 27)),
            if (task!.note.isNotEmpty) ...[
              const SizedBox(height: DayweaveSpacing.xs),
              Text(task!.note, style: Theme.of(context).textTheme.bodyLarge)
            ]
          ],
        ]),
      );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.all(DayweaveSpacing.xxl),
      child: Center(child: CircularProgressIndicator()));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(DayweaveSpacing.xxl),
      child: Column(children: [
        Text('Your tasks could not be loaded.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: DayweaveSpacing.md),
        FilledButton(onPressed: onRetry, child: const Text('Retry'))
      ]));
}
