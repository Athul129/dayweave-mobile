import 'package:flutter/widgets.dart';
import 'app.dart';
import 'core/config/app_config.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (config.isSupabaseConfigured) {
    await SupabaseService.initialize(config);
  }
  runApp(buildDayweaveApp(config));
}
