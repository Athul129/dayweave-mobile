import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_time/dayweave_date_time.dart';
import '../../../core/theme/dayweave_theme.dart';
import '../../../models/task.dart';
import '../../focus/presentation/focus_screen.dart';
import '../application/today_controller.dart';
import '../application/today_intention_controller.dart';
import '../application/today_state.dart';
import 'widgets/today_task_card.dart';
import 'widgets/today_task_form.dart';
import 'widgets/today_reflection_card.dart';
import 'widgets/today_reflection_screen.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});
  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late final TextEditingController _intentionController;
  late final FocusNode _intentionFocusNode;
  late final TextEditingController _brainDumpController;
  late final FocusNode _brainDumpFocusNode;
  @override
  void initState() {
    super.initState();
    _intentionController = TextEditingController();
    _intentionFocusNode = FocusNode();
    _brainDumpController = TextEditingController();
    _brainDumpFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _intentionController.dispose();
    _intentionFocusNode.dispose();
    _brainDumpController.dispose();
    _brainDumpFocusNode.dispose();
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
                SliverToBoxAdapter(
                    child: _RouteHeader(
                  selectors: selectors,
                  controller: _brainDumpController,
                  focusNode: _brainDumpFocusNode,
                  onSubmit: _openCreate,
                )),
                SliverToBoxAdapter(
                    child: _SearchFilterEntry(
                  activeCount: _activeFilterCount(state),
                  onTap: () => _showSearchFilterSheet(context, state),
                )),
                if (selectors.todayTasks.isEmpty)
                  const SliverToBoxAdapter(child: _EmptyRouteState())
                else if (selectors.filteredTasks.isEmpty)
                  const SliverToBoxAdapter(child: _FilteredEmptyState())
                else ...[
                  ..._sectionSlivers(selectors),
                  if (selectors.completedCount == selectors.totalCount)
                    const SliverToBoxAdapter(child: _CompletedDayState()),
                ],
                const SliverToBoxAdapter(child: _BreathingRoomFooter()),
                SliverToBoxAdapter(
                    child: _WebUpNextCard(
                        task: selectors.completedCount == selectors.totalCount
                            ? null
                            : selectors.upNext,
                        completed: selectors.todayTasks.isNotEmpty &&
                            selectors.completedCount == selectors.totalCount,
                        onFocus: _openFocusPreview)),
              SliverToBoxAdapter(
                  child: TodayReflectionCard(
                    onOpen: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const TodayReflectionScreen(),
                    )),
                  )),
              ],
              const SliverToBoxAdapter(
                  child: SizedBox(height: DayweaveSpacing.xl)),
            ]),
      )),
    );
  }

  List<Widget> _sectionSlivers(TodaySelectors selectors) => [
        _sectionSliver(selectors, TaskSection.morning, 'Morning', first: true),
        _sectionSliver(selectors, TaskSection.midday, 'Midday'),
        _sectionSliver(selectors, TaskSection.afternoon, 'Afternoon'),
      ];
  Widget _sectionSliver(
      TodaySelectors selectors, TaskSection section, String label,
      {bool first = false}) {
    final tasks = selectors.tasksFor(section);
    if (tasks.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
          DayweaveSpacing.lg,
          first ? DayweaveSpacing.sm : DayweaveSpacing.md,
          DayweaveSpacing.lg,
          0),
      sliver: SliverToBoxAdapter(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_sectionIcon(section),
                size: 16, color: _sectionColor(section)),
            const SizedBox(width: 6),
            Text(label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          ]),
          Text('${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}',
              style: Theme.of(context).textTheme.bodyMedium),
        ]),
        const SizedBox(height: DayweaveSpacing.sm),
        ...tasks.map((task) => Padding(
              padding: const EdgeInsets.only(bottom: DayweaveSpacing.xs),
              child: TodayTaskCard(
                  task: task,
                  selected: task.id == selectors.state.activeTaskId,
                  onSelect: () => ref
                      .read(todayControllerProvider.notifier)
                      .selectTask(task.id),
                  onToggleComplete: () => _toggleTask(task),
                  onEdit: () => _openEdit(task)),
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

  Future<void> _openCreate([String title = '']) async {
    if (title.trim().isEmpty) return;
    _brainDumpController.clear();
    await showTodayTaskFormSheet(
      context: context,
      today: ref.read(todayControllerProvider).date,
      initial: defaultTodayTaskDraft(ref.read(todayControllerProvider).date,
          title: title.trim()),
      onSave: (draft) =>
          ref.read(todayControllerProvider.notifier).createTask(draft),
    );
  }

  Future<void> _openEdit(Task task) async {
    await showTodayTaskFormSheet(
      context: context,
      today: ref.read(todayControllerProvider).date,
      editing: task,
      onSave: (draft) =>
          ref.read(todayControllerProvider.notifier).updateTask(task.id, draft),
      onDelete: () =>
          ref.read(todayControllerProvider.notifier).deleteTask(task.id),
    );
  }

  void _openFocusPreview() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const FocusScreen(),
    ));
  }

  int _activeFilterCount(TodayState state) =>
      (state.searchQuery.trim().isEmpty ? 0 : 1) +
      (state.statusFilter == TodayStatusFilter.all ? 0 : 1) +
      (state.energyFilter == TodayEnergyFilter.all ? 0 : 1) +
      (state.sectionFilter == TodaySectionFilter.all ? 0 : 1);

  Future<void> _showSearchFilterSheet(
      BuildContext context, TodayState state) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: DayweaveColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _SearchFilterSheet(
        activeCount: _activeFilterCount(state),
      ),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.date});
  final LocalDate date;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(DayweaveSpacing.lg,
            DayweaveSpacing.sm, DayweaveSpacing.lg, DayweaveSpacing.md),
        child: Row(children: [
          Expanded(
            child: Text(
                MaterialLocalizations.of(context)
                    .formatFullDate(date.asLocalDateTime),
                style: Theme.of(context).textTheme.titleMedium),
          ),
          PopupMenuButton<String>(
            tooltip: 'Today options',
            icon: const Icon(Icons.more_horiz),
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                  enabled: false, value: 'clear', child: Text('Clear View')),
              PopupMenuItem<String>(
                  enabled: false, value: 'share', child: Text('Share View')),
            ],
          ),
        ]),
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
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: const BoxDecoration(
          color: DayweaveColors.bluePaper, borderRadius: DayweaveRadii.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _SectionLabel(text: 'MORNING CHECK-IN'),
          Icon(Icons.auto_awesome_outlined,
              size: 18, color: DayweaveColors.marigold),
        ]),
        const SizedBox(height: 14),
        Text(state.value,
            style: text.displayMedium?.copyWith(fontSize: 31, height: 1.04)),
        const SizedBox(height: 7),
        Text('A little direction goes a long way.',
            style: text.bodyLarge?.copyWith(fontSize: 15, height: 1.3)),
        const SizedBox(height: 14),
        Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0x55D9DED8)),
              bottom: BorderSide(color: Color(0x55D9DED8)),
            ),
          ),
          child: Row(children: [
            const Icon(Icons.edit_outlined,
                size: 17, color: DayweaveColors.inkSoft),
            const SizedBox(width: 6),
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
                        style: text.bodyLarge?.copyWith(
                            fontSize: 14, color: DayweaveColors.inkSoft),
                        decoration: const InputDecoration(
                            isDense: true,
                            filled: false,
                            hintText: 'Set an intention for today',
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                            border: UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: Color(0x55D9DED8))),
                            enabledBorder: UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: Color(0x55D9DED8))),
                            focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                    color: Color(0xB3E8A229), width: 1)))))),
          ]),
        ),
        if (state.isLoading || state.isSaving) ...[
          const SizedBox(height: 6),
          Text('Saving…', style: text.bodyMedium?.copyWith(fontSize: 11))
        ],
        if (state.error != null) ...[
          const SizedBox(height: DayweaveSpacing.sm),
          Text('Your intention could not be saved. Please try again.',
              style: text.bodyMedium?.copyWith(color: DayweaveColors.coral))
        ],
        const SizedBox(height: 14),
        _ProgressSummary(selectors: selectors),
      ]),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.selectors});
  final TodaySelectors selectors;

  @override
  Widget build(BuildContext context) => Semantics(
        label:
            '${selectors.progress}% complete, ${selectors.completedCount} of ${selectors.totalCount} tasks, ${selectors.remainingMinutes} minutes left',
        child: Row(children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  TextSpan(
                      text: '${selectors.progress}% ',
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: DayweaveColors.ink)),
                  const TextSpan(text: 'clear', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 34, color: DayweaveColors.line),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${selectors.completedCount} of ${selectors.totalCount} tasks',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('${selectors.remainingMinutes} min left',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 13)),
                  ]),
            ),
          ),
        ]),
      );
}

// Kept temporarily for comparison while the presentation change is reviewed.
// ignore: unused_element
class _LegacyProgressSummary extends StatelessWidget {
  const _LegacyProgressSummary({required this.selectors});
  final TodaySelectors selectors;
  @override
  Widget build(BuildContext context) => Row(children: [
        Semantics(
            label:
                '${selectors.progress}% complete, ${selectors.completedCount} of ${selectors.totalCount} tasks',
            child: SizedBox(
                height: 78,
                width: 78,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(
                      height: 78,
                      width: 78,
                      child: CircularProgressIndicator(
                          value: selectors.progress / 100,
                          strokeWidth: 7,
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
  const _RouteHeader(
      {required this.selectors,
      required this.controller,
      required this.focusNode,
      required this.onSubmit});
  final TodaySelectors selectors;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;
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
          const SizedBox(height: DayweaveSpacing.lg),
          TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: onSubmit,
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              hintStyle: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontSize: 16, color: DayweaveColors.inkSoft),
              hintText: 'What’s taking up space?',
              prefixIcon: const Icon(Icons.add,
                  color: DayweaveColors.marigold, size: 19),
              suffixIcon: IconButton(
                tooltip: 'Add task',
                onPressed: () => onSubmit(controller.text),
                icon: const Icon(Icons.arrow_forward,
                    size: 19, color: DayweaveColors.inkSoft),
              ),
              border: const UnderlineInputBorder(
                  borderSide: BorderSide(color: DayweaveColors.line)),
              enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: DayweaveColors.line)),
              focusedBorder: const UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: DayweaveColors.marigold, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: DayweaveSpacing.sm, vertical: DayweaveSpacing.sm),
            ),
          ),
        ]),
      );
}

class _SearchFilterEntry extends StatelessWidget {
  const _SearchFilterEntry({required this.activeCount, required this.onTap});
  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            DayweaveSpacing.lg, 0, DayweaveSpacing.lg, DayweaveSpacing.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: DayweaveRadii.sm,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: DayweaveSpacing.sm),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DayweaveColors.line)),
            ),
            child: Row(children: [
              const Icon(Icons.search, size: 19, color: DayweaveColors.inkSoft),
              const SizedBox(width: DayweaveSpacing.sm),
              Expanded(
                child: Text('Search & filter',
                    style: Theme.of(context).textTheme.bodyLarge),
              ),
              if (activeCount > 0)
                Text('· $activeCount active',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DayweaveColors.inkSoft)),
              const SizedBox(width: DayweaveSpacing.sm),
              const Icon(Icons.arrow_forward,
                  size: 18, color: DayweaveColors.inkSoft),
            ]),
          ),
        ),
      );
}

class _SearchFilterSheet extends StatelessWidget {
  const _SearchFilterSheet({required this.activeCount});
  final int activeCount;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            DayweaveSpacing.lg, DayweaveSpacing.md, DayweaveSpacing.lg,
            DayweaveSpacing.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: DayweaveColors.line,
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: DayweaveSpacing.lg),
          Text('Search tasks',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: DayweaveSpacing.md),
          const _DisabledSearchField(),
          const SizedBox(height: DayweaveSpacing.lg),
          const _FilterGroup(label: 'Status', options: ['All', 'Active', 'Completed']),
          const _FilterGroup(label: 'Energy', options: ['All', 'Deep', 'Light', 'Social']),
          const _FilterGroup(label: 'Section', options: ['All', 'Morning', 'Midday', 'Afternoon']),
          const SizedBox(height: DayweaveSpacing.sm),
          TextButton.icon(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: DayweaveColors.marigold,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: DayweaveSpacing.sm),
            ),
            icon: const Icon(Icons.refresh, size: 17),
            label: const Text('Clear filters'),
          ),
        ]),
      );
}

class _DisabledSearchField extends StatelessWidget {
  const _DisabledSearchField();

  @override
  Widget build(BuildContext context) => Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: DayweaveSpacing.md),
        decoration: BoxDecoration(
          color: DayweaveColors.card,
          border: Border.all(color: DayweaveColors.line),
          borderRadius: DayweaveRadii.md,
        ),
        child: Row(children: [
          const Icon(Icons.search, color: DayweaveColors.inkSoft),
          const SizedBox(width: DayweaveSpacing.sm),
          Text('Search tasks', style: Theme.of(context).textTheme.bodyLarge),
          const Spacer(),
          const Icon(Icons.close, size: 18, color: DayweaveColors.line),
        ]),
      );
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({required this.label, required this.options});
  final String label;
  final List<String> options;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: DayweaveSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: DayweaveColors.inkSoft, letterSpacing: 1.1)),
          const SizedBox(height: DayweaveSpacing.sm),
          Wrap(
            spacing: DayweaveSpacing.sm,
            runSpacing: DayweaveSpacing.sm,
            children: options
                .map((option) => Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(
                          horizontal: DayweaveSpacing.md, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: DayweaveColors.line),
                        borderRadius: DayweaveRadii.sm,
                      ),
                      child: Text(option,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ))
                .toList(),
          ),
        ]),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            DayweaveSpacing.lg, 0, DayweaveSpacing.lg, DayweaveSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 1, color: DayweaveColors.line),
          const SizedBox(height: DayweaveSpacing.xl),
          Text('Your route is open.',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontSize: 25)),
          const SizedBox(height: DayweaveSpacing.xs),
          Text(
              'Capture one thought above, then give it a time and a little shape.',
              style: Theme.of(context).textTheme.bodyLarge),
        ]),
      );
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            DayweaveSpacing.lg, DayweaveSpacing.md, DayweaveSpacing.lg, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('No tasks match',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: DayweaveSpacing.xs),
          Text('Try a different search or clear your filters.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: DayweaveSpacing.sm),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: DayweaveColors.marigold,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: DayweaveSpacing.sm),
            ),
            child: const Text('Clear filters'),
          ),
        ]),
      );
}

class _CompletedDayState extends StatelessWidget {
  const _CompletedDayState();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            DayweaveSpacing.lg, DayweaveSpacing.md, DayweaveSpacing.lg, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text('The route is complete.\nYou gave today some shape.',
                style: Theme.of(context).textTheme.bodyLarge),
          ),
          const OutlinedButton(
            onPressed: null,
            child: Text('Reflect'),
          ),
        ]),
      );
}

class _BreathingRoomFooter extends StatelessWidget {
  const _BreathingRoomFooter();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(DayweaveSpacing.lg,
            DayweaveSpacing.lg, DayweaveSpacing.lg, DayweaveSpacing.md),
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

// ignore: unused_element
class _UpNextCard extends StatelessWidget {
  const _UpNextCard({required this.task, required this.onFocus});
  final Task? task;
  final VoidCallback onFocus;
  final bool completed = false;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: DayweaveSpacing.lg),
        padding: const EdgeInsets.symmetric(
            horizontal: DayweaveSpacing.lg, vertical: DayweaveSpacing.sm),
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
          const SizedBox(height: DayweaveSpacing.xs),
          if (completed) ...[
            Text('The route is complete.',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontSize: 23)),
            const SizedBox(height: DayweaveSpacing.sm),
            Text('You gave today some shape.',
                style: Theme.of(context).textTheme.bodyLarge)
          ] else if (task == null) ...[
            Text('Nothing pressing.',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontSize: 23)),
            const SizedBox(height: DayweaveSpacing.sm),
            Text('You made it to the other side of the list.',
                style: Theme.of(context).textTheme.bodyLarge)
          ] else ...[
            Text('${task!.time} · ${task!.minutes} min · ${task!.energy.name}',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: DayweaveSpacing.sm),
            Text(task!.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: DayweaveSpacing.sm),
            Row(children: [
              OutlinedButton.icon(
                onPressed: onFocus,
                icon: const Icon(Icons.play_arrow, size: 17),
                label: const Text('Focus'),
              ),
              const SizedBox(width: DayweaveSpacing.sm),
              const TextButton(onPressed: null, child: Text('Later')),
            ]),
          ],
        ]),
      );
}

class _WebUpNextCard extends StatelessWidget {
  const _WebUpNextCard({required this.task, required this.onFocus, this.completed = false});

  final Task? task;
  final VoidCallback onFocus;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final activeTask = task;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DayweaveSpacing.lg),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: DayweaveColors.sage,
        borderRadius: DayweaveRadii.lg,
        boxShadow: [BoxShadow(color: Color(0x1A243B32), offset: Offset(0, 5), blurRadius: 14)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 17, 20, 12),
          child: Row(children: [
            const Icon(Icons.circle, size: 12, color: DayweaveColors.marigold),
            const SizedBox(width: DayweaveSpacing.sm),
            const _SectionLabel(text: 'UP NEXT'),
            const Spacer(),
            if (activeTask != null)
              Text(activeTask.time,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: 'Fraunces', color: DayweaveColors.inkSoft)),
          ]),
        ),
        if (activeTask != null && !completed) ...[
          SizedBox(
            height: 140,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset('assets/images/dayweave-morning.webp', fit: BoxFit.cover),
              Positioned(
                right: 11,
                bottom: 9,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  color: const Color(0xAA1D2D35),
                  child: const Text('PLATE 01 / MORNING LIGHT',
                      style: TextStyle(color: Colors.white, fontSize: 8, letterSpacing: 1.0)),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${activeTask.energy.name.toUpperCase()} ENERGY · ${activeTask.minutes}m',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: DayweaveColors.inkSoft,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3)),
              const SizedBox(height: 10),
              Text(activeTask.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 30, height: 1.05)),
              const SizedBox(height: 7),
              Text(activeTask.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DayweaveColors.inkSoft)),
              const SizedBox(height: 18),
              Wrap(spacing: DayweaveSpacing.sm, runSpacing: DayweaveSpacing.sm, children: [
                OutlinedButton.icon(
                  onPressed: onFocus,
                  icon: const Icon(Icons.play_arrow, size: 17),
                  label: const Text('Start focus'),
                ),
                const TextButton(onPressed: null, child: Text('Later')),
              ]),
            ]),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(completed ? 'The route is complete.' : 'Nothing pressing.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 23)),
              const SizedBox(height: DayweaveSpacing.sm),
              Text(completed ? 'You gave today some shape.' : 'You made it to the other side of the list.',
                  style: Theme.of(context).textTheme.bodyLarge),
            ]),
          ),
      ]),
    );
  }
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
