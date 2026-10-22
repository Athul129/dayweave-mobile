import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dayweave_theme.dart';
import '../../application/today_reflection_controller.dart';

class TodayReflectionScreen extends ConsumerStatefulWidget {
  const TodayReflectionScreen({
    this.intention,
    this.completedCount = 2,
    this.remainingCount = 1,
    this.plannedMinutes = 30,
    super.key,
  });

  final String? intention;
  final int completedCount;
  final int remainingCount;
  final int plannedMinutes;

  @override
  ConsumerState<TodayReflectionScreen> createState() =>
      _TodayReflectionScreenState();
}

class _TodayReflectionScreenState extends ConsumerState<TodayReflectionScreen> {
  late final TextEditingController _wentWellController;
  late final TextEditingController _carryForwardController;
  late final FocusNode _wentWellFocus;
  late final FocusNode _carryForwardFocus;

  @override
  void initState() {
    super.initState();
    _wentWellController = TextEditingController();
    _carryForwardController = TextEditingController();
    _wentWellFocus = FocusNode();
    _carryForwardFocus = FocusNode();
    Future<void>.microtask(() {
      if (mounted) {
        ref.read(todayReflectionProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _wentWellController.dispose();
    _carryForwardController.dispose();
    _wentWellFocus.dispose();
    _carryForwardFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reflection = ref.watch(todayReflectionProvider);
    return Scaffold(
      backgroundColor: DayweaveColors.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(DayweaveSpacing.lg,
              DayweaveSpacing.md, DayweaveSpacing.lg, DayweaveSpacing.xl),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _syncControllers(reflection),
            _ReflectionHeader(onBack: () => Navigator.of(context).pop()),
            const SizedBox(height: DayweaveSpacing.xl),
            Text('What mattered today?',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontSize: 34, height: 1.05)),
            const SizedBox(height: DayweaveSpacing.sm),
            Text('A quiet look at the shape of your day.',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: DayweaveColors.inkSoft, height: 1.45)),
            if (reflection.isLoading) ...[
              const SizedBox(height: DayweaveSpacing.sm),
              const LinearProgressIndicator(color: DayweaveColors.marigold),
            ],
            if (reflection.error != null) ...[
              const SizedBox(height: DayweaveSpacing.sm),
              Text(
                reflection.errorKind == TodayReflectionErrorKind.load
                    ? 'Your reflection could not be loaded. Please try again.'
                    : 'Your reflection could not be saved. Please try again.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: DayweaveColors.coral),
              ),
              if (reflection.errorKind == TodayReflectionErrorKind.load)
                TextButton(
                  onPressed: reflection.isLoading
                      ? null
                      : ref.read(todayReflectionProvider.notifier).load,
                  child: const Text('Try again'),
                ),
            ],
            const SizedBox(height: 36),
            _IntentionSurface(intention: widget.intention),
            const SizedBox(height: 36),
            const _ReflectionSectionLabel('YOUR DAY'),
            const SizedBox(height: DayweaveSpacing.md),
            Text('You made some movement today.',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: DayweaveColors.inkSoft, height: 1.4)),
            const SizedBox(height: DayweaveSpacing.lg),
            _ReflectionMetrics(
              completed: widget.completedCount,
              remaining: widget.remainingCount,
              plannedMinutes: widget.plannedMinutes,
            ),
            const SizedBox(height: 36),
            const _ReflectionSectionLabel('FOCUS'),
            const SizedBox(height: DayweaveSpacing.md),
            const _FocusEmptySurface(),
            const SizedBox(height: 36),
            const Divider(color: DayweaveColors.line, height: 1),
            const SizedBox(height: 32),
            const _ReflectionSectionLabel('BEFORE YOU GO'),
            const SizedBox(height: DayweaveSpacing.lg),
            _ReflectionField(
              label: 'What went well?',
              hint: 'A few words about today...',
              controller: _wentWellController,
              focusNode: _wentWellFocus,
              onChanged:
                  ref.read(todayReflectionProvider.notifier).updateWentWell,
            ),
            const SizedBox(height: DayweaveSpacing.lg),
            _ReflectionField(
              label: 'What should carry forward?',
              hint: 'Something for tomorrow...',
              controller: _carryForwardController,
              focusNode: _carryForwardFocus,
              onChanged:
                  ref.read(todayReflectionProvider.notifier).updateCarryForward,
            ),
            const SizedBox(height: DayweaveSpacing.xl),
            LayoutBuilder(
              builder: (context, constraints) => Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text('Take what matters with you.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontFamily: 'Fraunces',
                            fontStyle: FontStyle.italic,
                            color: DayweaveColors.inkSoft)),
                  ),
                  const SizedBox(width: DayweaveSpacing.sm),
                  SizedBox(
                    width: constraints.maxWidth < 360 ? 150 : 170,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.north_east, size: 17),
                      label: Text(
                          reflection.isSaving ? 'Saving...' : 'Done for today'),
                      style: FilledButton.styleFrom(
                        backgroundColor: DayweaveColors.marigold,
                        foregroundColor: DayweaveColors.ink,
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _syncControllers(TodayReflectionState state) {
    if (!_wentWellFocus.hasFocus &&
        _wentWellController.text != state.wentWell) {
      _wentWellController.text = state.wentWell;
    }
    if (!_carryForwardFocus.hasFocus &&
        _carryForwardController.text != state.carryForward) {
      _carryForwardController.text = state.carryForward;
    }
    return const SizedBox.shrink();
  }

  Future<void> _save() async {
    final controller = ref.read(todayReflectionProvider.notifier);
    try {
      await controller.save();
    } catch (_) {
      return;
    }
    if (mounted && ref.read(todayReflectionProvider).error == null) {
      Navigator.of(context).pop();
    }
  }
}

class _ReflectionHeader extends StatelessWidget {
  const _ReflectionHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 26),
          color: DayweaveColors.ink,
          tooltip: 'Back',
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: EdgeInsets.zero,
        ),
        const Spacer(),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.circle, size: 15, color: DayweaveColors.marigold),
          const SizedBox(width: DayweaveSpacing.sm),
          Text('DAILY REFLECTION',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: DayweaveColors.inkSoft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0)),
        ]),
        const Spacer(),
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.close, size: 28),
          color: DayweaveColors.ink,
          tooltip: 'Close',
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: EdgeInsets.zero,
        ),
      ]);
}

class _IntentionSurface extends StatelessWidget {
  const _IntentionSurface({this.intention});
  final String? intention;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DayweaveColors.card.withValues(alpha: .72),
          border: Border.all(color: DayweaveColors.line),
          borderRadius: DayweaveRadii.lg,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _ReflectionSectionLabel('YOUR INTENTION'),
          const SizedBox(height: DayweaveSpacing.md),
          Text(intention ?? 'Make room for one thing that matters.',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(height: 1.2)),
        ]),
      );
}

class _ReflectionSectionLabel extends StatelessWidget {
  const _ReflectionSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: DayweaveColors.inkSoft,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0));
}

class _ReflectionMetrics extends StatelessWidget {
  const _ReflectionMetrics(
      {required this.completed,
      required this.remaining,
      required this.plannedMinutes});
  final int completed;
  final int remaining;
  final int plannedMinutes;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, __) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _Metric(
                    icon: Icons.check,
                    value: '$completed',
                    label: 'completed')),
            SizedBox(width: DayweaveSpacing.xs),
            Expanded(
                child: _Metric(
                    icon: Icons.north_east,
                    value: '$remaining',
                    label: 'remaining')),
            SizedBox(width: DayweaveSpacing.xs),
            Expanded(
                child: _Metric(
                    icon: Icons.schedule,
                    value: '$plannedMinutes min',
                    label: 'planned')),
          ],
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: DayweaveColors.sage.withValues(alpha: .45),
              child: Icon(icon, size: 19, color: DayweaveColors.inkSoft),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(value,
                    maxLines: 1,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontSize: 24)),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(label,
                  maxLines: 1,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 11)),
            ),
          ),
        ],
      );
}

class _FocusEmptySurface extends StatelessWidget {
  const _FocusEmptySurface();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DayweaveColors.card.withValues(alpha: .45),
          borderRadius: DayweaveRadii.lg,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('No focus sessions today.',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontSize: 22)),
          const SizedBox(height: DayweaveSpacing.xs),
          Text("That’s okay. Every day looks different.",
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: DayweaveColors.inkSoft)),
        ]),
      );
}

class _ReflectionField extends StatelessWidget {
  const _ReflectionField(
      {required this.label,
      required this.hint,
      required this.controller,
      required this.focusNode,
      required this.onChanged});
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: DayweaveSpacing.sm),
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          minLines: 3,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: DayweaveColors.inkSoft.withValues(alpha: .55)),
            filled: true,
            fillColor: DayweaveColors.card.withValues(alpha: .48),
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: DayweaveColors.line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: DayweaveColors.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide:
                    const BorderSide(color: DayweaveColors.sage, width: 2)),
          ),
        ),
      ]);
}
