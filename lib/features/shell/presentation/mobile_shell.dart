import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dayweave_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../account/presentation/account_avatar_action.dart';
import '../../preferences/presentation/preferences_sheet.dart';
import '../../weather/application/weather_controller.dart';
import '../../weather/application/weather_lifecycle_coordinator.dart';

class MobileShell extends ConsumerStatefulWidget {
  const MobileShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;
  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell> {
  int get index => widget.navigationShell.currentIndex;
  late final WeatherLifecycleCoordinator _weatherLifecycle;
  bool _backHandling = false;
  bool _logoutDialogOpen = false;
  static const destinations = ['Today', 'Week', 'Notes', 'History'];
  /* legacy placeholder removed
    ('This Week', 'Monday–Sunday planning will live here.'),
    legacy placeholder removed */

  @override
  void initState() {
    super.initState();
    _weatherLifecycle = WeatherLifecycleCoordinator(
      controller: ref.read(weatherProvider.notifier),
    )..start();
  }

  @override
  void dispose() {
    _weatherLifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_backHandling) {
          _handleSystemBack();
        }
      },
      child: Scaffold(
        backgroundColor: DayweaveColors.paper,
        appBar: AppBar(
          toolbarHeight: 68,
          titleSpacing: DayweaveSpacing.lg,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/dayweave-mark.webp',
                width: 30,
                height: 30,
              ),
              const SizedBox(width: DayweaveSpacing.sm),
              Text(
                'dayweave',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontSize: 24),
              ),
            ],
          ),
          actions: [
            IconButton(
                tooltip: 'Preferences',
                onPressed: () => showPreferencesSheet(context),
                icon: const Icon(Icons.tune_outlined)),
            AccountAvatarAction(onSignOut: _showSignOutConfirmation),
            IconButton(
              tooltip: 'Sign out',
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: widget.navigationShell,
            ),
          ],
        ),
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
            onDestinationSelected: widget.navigationShell.goBranch,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today),
                label: destinations[0],
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_view_week_outlined),
                selectedIcon: Icon(Icons.calendar_view_week),
                label: destinations[1],
              ),
              NavigationDestination(
                icon: Icon(Icons.inbox_outlined),
                selectedIcon: Icon(Icons.inbox),
                label: destinations[2],
              ),
              NavigationDestination(
                icon: Icon(Icons.timer_outlined),
                selectedIcon: Icon(Icons.timer),
                label: destinations[3],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSystemBack() async {
    if (_backHandling || !mounted) return;
    _backHandling = true;
    try {
      final branchNavigator = widget
          .navigationShell.route.branches[index].navigatorKey.currentState;
      if (branchNavigator != null && await branchNavigator.maybePop()) return;
      if (!mounted) return;

      if (index != 0) {
        widget.navigationShell.goBranch(0);
      } else {
        await _signOut(context);
      }
    } finally {
      _backHandling = false;
    }
  }

  Future<void> _signOut(BuildContext context) async {
    if (_logoutDialogOpen) return;
    _logoutDialogOpen = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Do you want to logout?'),
        content: const Text('You can sign back in whenever you are ready.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    try {
      if (confirmed == true && mounted) {
        await ref.read(authControllerProvider.notifier).signOut();
      }
    } finally {
      _logoutDialogOpen = false;
    }
  }

  void _showSignOutConfirmation() => _signOut(context);
}
