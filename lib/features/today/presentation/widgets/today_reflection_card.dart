import 'package:flutter/material.dart';

import '../../../../core/theme/dayweave_theme.dart';

class TodayReflectionCard extends StatelessWidget {
  const TodayReflectionCard({required this.onOpen, super.key});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            DayweaveSpacing.lg, DayweaveSpacing.lg, DayweaveSpacing.lg, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageWidth = constraints.maxWidth * .44;
            return ClipRRect(
              borderRadius: DayweaveRadii.md,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(color: Color(0xFFF1E5CD)),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'LATER, MAYBE',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: DayweaveColors.inkSoft,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Close the loop gently.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontSize: 20,
                                      height: 1.05,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Three minutes to notice what moved.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: DayweaveColors.inkSoft,
                                      height: 1.35,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Semantics(
                                button: true,
                                label: 'Open reflection',
                                child: InkWell(
                                  onTap: onOpen,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Open reflection',
                                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                                color: DayweaveColors.inkSoft,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(width: DayweaveSpacing.xs),
                                        const Icon(Icons.north_east, size: 17, color: DayweaveColors.inkSoft),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: imageWidth,
                      child: Image.asset(
                        'assets/images/dayweave-reflection.webp',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}
