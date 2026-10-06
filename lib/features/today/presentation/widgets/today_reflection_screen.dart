import 'package:flutter/material.dart';

import '../../../../core/theme/dayweave_theme.dart';

class TodayReflectionScreen extends StatelessWidget {
  const TodayReflectionScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: DayweaveColors.paper,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                DayweaveSpacing.lg, DayweaveSpacing.md, DayweaveSpacing.lg, DayweaveSpacing.xl),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _ReflectionHeader(onBack: () => Navigator.of(context).pop()),
              const SizedBox(height: DayweaveSpacing.xl),
              Text('What mattered today?',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: 34, height: 1.05)),
              const SizedBox(height: DayweaveSpacing.sm),
              Text('A quiet look at the shape of your day.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: DayweaveColors.inkSoft, height: 1.45)),
              const SizedBox(height: 36),
              const _IntentionSurface(),
              const SizedBox(height: 36),
              const _ReflectionSectionLabel('YOUR DAY'),
              const SizedBox(height: DayweaveSpacing.md),
              Text('You made some movement today.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: DayweaveColors.inkSoft, height: 1.4)),
              const SizedBox(height: DayweaveSpacing.lg),
              const _ReflectionMetrics(),
              const SizedBox(height: 36),
              const _ReflectionSectionLabel('FOCUS'),
              const SizedBox(height: DayweaveSpacing.md),
              const _FocusEmptySurface(),
              const SizedBox(height: 36),
              const Divider(color: DayweaveColors.line, height: 1),
              const SizedBox(height: 32),
              const _ReflectionSectionLabel('BEFORE YOU GO'),
              const SizedBox(height: DayweaveSpacing.lg),
              const _ReflectionField(label: 'What went well?', hint: 'A few words about today...'),
              const SizedBox(height: DayweaveSpacing.lg),
              const _ReflectionField(
                  label: 'What should carry forward?', hint: 'Something for tomorrow...'),
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
                        onPressed: () {},
                        icon: const Icon(Icons.north_east, size: 17),
                        label: const Text('Done for today'),
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
  const _IntentionSurface();

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
          Text('Make room for one thing that matters.',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(height: 1.2)),
        ]),
      );
}

class _ReflectionSectionLabel extends StatelessWidget {
  const _ReflectionSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: DayweaveColors.inkSoft, fontWeight: FontWeight.w700, letterSpacing: 2.0));
}

class _ReflectionMetrics extends StatelessWidget {
  const _ReflectionMetrics();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, __) => const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Metric(icon: Icons.check, value: '2', label: 'completed')),
            SizedBox(width: DayweaveSpacing.xs),
            Expanded(child: _Metric(icon: Icons.north_east, value: '1', label: 'remaining')),
            SizedBox(width: DayweaveSpacing.xs),
            Expanded(child: _Metric(icon: Icons.schedule, value: '30 min', label: 'planned')),
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
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 24)),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
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
          Text('No focus sessions today.', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 22)),
          const SizedBox(height: DayweaveSpacing.xs),
          Text("That’s okay. Every day looks different.",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: DayweaveColors.inkSoft)),
        ]),
      );
}

class _ReflectionField extends StatelessWidget {
  const _ReflectionField({required this.label, required this.hint});
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: DayweaveSpacing.sm),
        TextField(
          minLines: 3,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: DayweaveColors.inkSoft.withValues(alpha: .55)),
            filled: true,
            fillColor: DayweaveColors.card.withValues(alpha: .48),
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: DayweaveColors.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: DayweaveColors.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: DayweaveColors.sage, width: 2)),
          ),
        ),
      ]);
}
