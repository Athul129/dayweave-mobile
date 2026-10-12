import 'package:flutter/material.dart';

import '../../../core/theme/dayweave_theme.dart';

class PreferenceDurationOption extends StatelessWidget {
  const PreferenceDurationOption(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.fullWidth = false,
      super.key});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: DayweaveRadii.md,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? DayweaveColors.sage.withValues(alpha: .38)
                : DayweaveColors.card,
            border: Border.all(
                color: selected ? DayweaveColors.inkSoft : DayweaveColors.line),
            borderRadius: DayweaveRadii.md,
          ),
          child: Row(children: [
            Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color:
                    selected ? Colors.green.shade700 : DayweaveColors.inkSoft),
            const SizedBox(width: 10),
            Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DayweaveColors.ink, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
