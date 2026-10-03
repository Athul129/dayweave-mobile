import 'package:flutter/material.dart';

import '../../../../core/theme/dayweave_theme.dart';
import '../../../../models/task.dart';

class TodayTaskCard extends StatelessWidget {
  const TodayTaskCard(
      {required this.task,
      required this.selected,
      required this.onSelect,
      required this.onToggleComplete,
      required this.onEdit,
      super.key});
  final Task task;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onToggleComplete;
  final VoidCallback onEdit;
  String get _energyLabel => switch (task.energy) {
        TaskEnergy.deep => 'Deep',
        TaskEnergy.light => 'Light',
        TaskEnergy.social => 'Social'
      };
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final surface = selected
        ? DayweaveColors.bluePaper.withValues(alpha: .45)
        : Colors.transparent;
    return Semantics(
      container: true,
      label:
          '${task.title}, ${task.time}, ${task.minutes} minutes, $_energyLabel',
      child: Material(
        color: surface,
        child: InkWell(
          onTap: onSelect,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(vertical: DayweaveSpacing.sm),
            decoration: BoxDecoration(
              border: Border(
                bottom: const BorderSide(color: DayweaveColors.line),
                left: selected
                    ? const BorderSide(color: DayweaveColors.marigold, width: 2)
                    : BorderSide.none,
              ),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                label:
                    '${task.done ? 'Mark incomplete' : 'Complete'} ${task.title}',
                button: true,
                child: Checkbox(
                  value: task.done,
                  onChanged: (_) => onToggleComplete(),
                  activeColor: DayweaveColors.ink,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: DayweaveSpacing.sm),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(task.time, style: text.labelMedium),
                        const SizedBox(width: DayweaveSpacing.sm),
                        Expanded(
                          child: Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(
                              color: task.done
                                  ? DayweaveColors.inkSoft
                                  : DayweaveColors.ink,
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: DayweaveSpacing.xs),
                      Wrap(
                        spacing: DayweaveSpacing.sm,
                        children: [
                          Text('${task.minutes} min', style: text.labelMedium),
                          Text(_energyLabel,
                              style: text.labelMedium
                                  ?.copyWith(color: DayweaveColors.marigold)),
                        ],
                      ),
                      if (task.note.isNotEmpty) ...[
                        const SizedBox(height: DayweaveSpacing.xs),
                        Text(task.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium),
                      ],
                    ]),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  tooltip: 'Edit ${task.title}',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  padding: EdgeInsets.zero,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
