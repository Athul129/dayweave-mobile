import 'package:flutter/material.dart';
import '../core/theme/dayweave_theme.dart';

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({required this.title, required this.description, super.key});
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(title: Text(title), pinned: true, backgroundColor: DayweaveColors.paper),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(DayweaveSpacing.xxl),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Image.asset('assets/images/dayweave-mark.webp', width: 74, height: 74),
                    const SizedBox(height: DayweaveSpacing.xl),
                    Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: DayweaveSpacing.sm),
                    Text(description, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                    const SizedBox(height: DayweaveSpacing.lg),
                    const Text('Foundation ready · feature implementation follows in a later phase.'),
                  ]),
                ),
              ),
            ),
          ],
        ),
      );
}
