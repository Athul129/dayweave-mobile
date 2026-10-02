import 'package:flutter/material.dart';

import '../../../../core/theme/dayweave_theme.dart';
import '../../../../models/task.dart';

class TodayTaskCard extends StatelessWidget {
  const TodayTaskCard(
      {required this.task,
      required this.selected,
      required this.onSelect,
      required this.onToggleComplete,
      super.key});
  final Task task;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onToggleComplete;
  String get _energyLabel => switch (task.energy) {
        TaskEnergy.deep => 'Deep',
        TaskEnergy.light => 'Light',
        TaskEnergy.social => 'Social'
      };
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: selected ? DayweaveColors.bluePaper : DayweaveColors.card,
      shape: RoundedRectangleBorder(
          borderRadius: DayweaveRadii.md,
          side: BorderSide(
              color: selected ? DayweaveColors.marigold : DayweaveColors.line)),
      child: InkWell(
          borderRadius: DayweaveRadii.md,
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.all(DayweaveSpacing.sm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                  label:
                      '${task.done ? 'Mark incomplete' : 'Complete'} ${task.title}',
                  child: Checkbox(
                      value: task.done,
                      onChanged: (_) => onToggleComplete(),
                      activeColor: DayweaveColors.ink,
                      visualDensity: VisualDensity.compact)),
              const SizedBox(width: DayweaveSpacing.sm),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Wrap(
                        spacing: DayweaveSpacing.sm,
                        runSpacing: DayweaveSpacing.xs,
                        children: [
                          Text(task.time, style: text.labelMedium),
                          Text(_energyLabel,
                              style: text.labelMedium
                                  ?.copyWith(color: DayweaveColors.marigold)),
                          Text('${task.minutes} min', style: text.labelMedium)
                        ]),
                    const SizedBox(height: DayweaveSpacing.xs),
                    Text(task.title,
                        style: text.titleMedium?.copyWith(
                            color: task.done
                                ? DayweaveColors.inkSoft
                                : DayweaveColors.ink)),
                    if (task.note.isNotEmpty) ...[
                      const SizedBox(height: DayweaveSpacing.xs),
                      Text(task.note, style: text.bodyMedium)
                    ],
                  ])),
            ]),
          )),
    );
  }
}
