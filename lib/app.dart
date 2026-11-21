import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'core/routing/app_router.dart';
import 'core/theme/dayweave_theme.dart';

class DayweaveApp extends ConsumerWidget {
  const DayweaveApp({required this.config, super.key});
  final AppConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = DayweaveTheme.light();
    if (!config.isSupabaseConfigured) {
      return MaterialApp(
        title: 'Dayweave',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const ConfigurationRequiredScreen(),
      );
    }
    return MaterialApp.router(
      title: 'Dayweave',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

class ConfigurationRequiredScreen extends StatelessWidget {
  const ConfigurationRequiredScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/dayweave-mark.webp',
                        width: 74, height: 74),
                    const SizedBox(height: 24),
                    Text('Connect Dayweave',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    const Text(
                        'Provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY with dart-define before running the mobile client.',
                        textAlign: TextAlign.center),
                  ]),
            ),
          ),
        ),
      );
}

Widget buildDayweaveApp(AppConfig config) =>
    ProviderScope(child: DayweaveApp(config: config));
