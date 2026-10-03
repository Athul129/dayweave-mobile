import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dayweave_theme.dart';
import '../../../widgets/feature_placeholder.dart';
import '../../auth/application/auth_controller.dart';
import '../../today/presentation/today_screen.dart';

class MobileShell extends ConsumerStatefulWidget {
  const MobileShell({super.key});
  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell> {
  int index = 0;
  static const destinations = [
    ('Today', 'Your daily route will live here.'),
    ('This Week', 'Monday–Sunday planning will live here.'),
    ('Loose Notes', 'Your quiet notebook will live here.'),
    ('Focus History', 'Completed focus sessions will live here.'),
  ];

  @override
  Widget build(BuildContext context) {
    final destination = destinations[index];
    return Scaffold(
      backgroundColor: DayweaveColors.paper,
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: DayweaveSpacing.lg,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/dayweave-mark.webp',
                width: 30, height: 30),
            const SizedBox(width: DayweaveSpacing.sm),
            Text('dayweave',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontSize: 24)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: index == 0
          ? const TodayScreen()
          : FeaturePlaceholder(
              title: destination.$1, description: destination.$2),
      bottomNavigationBar: NavigationBarTheme(
        data: Theme.of(context).navigationBarTheme.copyWith(
              backgroundColor: DayweaveColors.paper,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              indicatorColor: DayweaveColors.sage.withValues(alpha: .7),
              elevation: 0,
            ),
        child: NavigationBar(
          height: 80,
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today),
                label: 'Today'),
            NavigationDestination(
                icon: Icon(Icons.calendar_view_week_outlined),
                selectedIcon: Icon(Icons.calendar_view_week),
                label: 'Week'),
            NavigationDestination(
                icon: Icon(Icons.inbox_outlined),
                selectedIcon: Icon(Icons.inbox),
                label: 'Notes'),
            NavigationDestination(
                icon: Icon(Icons.timer_outlined),
                selectedIcon: Icon(Icons.timer),
                label: 'History'),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in whenever you are ready.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}
