import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'core/theme/dayweave_theme.dart';
import 'features/shell/presentation/mobile_shell.dart';
import 'features/auth/application/auth_session_provider.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/presentation/auth_error.dart';

class DayweaveApp extends StatelessWidget {
  const DayweaveApp({required this.config, super.key});
  final AppConfig config;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Dayweave',
        debugShowCheckedModeBanner: false,
        theme: DayweaveTheme.light(),
        home: config.isSupabaseConfigured ? const AuthGate() : const ConfigurationRequiredScreen(),
      );
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authSessionProvider);
    return switch (state) {
      AuthInitializing() => const _AuthLoadingScreen(),
      AuthSignedOut() => const AuthScreen(),
      AuthSignedIn() => const MobileShell(),
      AuthSessionError(:final error) => _AuthErrorScreen(message: authErrorMessage(error)),
    };
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Image(image: AssetImage('assets/images/dayweave-mark.webp'), width: 72), SizedBox(height: 20), CircularProgressIndicator()])));
}

class _AuthErrorScreen extends StatelessWidget {
  const _AuthErrorScreen({required this.message});
  final String message;
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('We could not restore your session.\n\n$message', textAlign: TextAlign.center))));
}

class ConfigurationRequiredScreen extends StatelessWidget {
  const ConfigurationRequiredScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Image.asset('assets/images/dayweave-mark.webp', width: 74, height: 74),
                const SizedBox(height: 24),
                Text('Connect Dayweave', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                const Text('Provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY with dart-define before running the mobile client.', textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      );
}

Widget buildDayweaveApp(AppConfig config) => ProviderScope(child: DayweaveApp(config: config));
