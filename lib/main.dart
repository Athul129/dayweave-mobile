import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'app.dart';
import 'core/config/app_config.dart';
import 'core/theme/dayweave_theme.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: DayweaveColors.paper,
    systemNavigationBarDividerColor: DayweaveColors.paper,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  ));
  final config = AppConfig.fromEnvironment();
  if (config.isSupabaseConfigured) {
    await SupabaseService.initialize(config);
  }
  runApp(buildDayweaveApp(config));
}
