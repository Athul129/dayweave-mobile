import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';

class SupabaseService {
  const SupabaseService._();

  static Future<Supabase> initialize(AppConfig config) async {
    config.validate();
    return Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
    );
  }

  static SupabaseClient client() => Supabase.instance.client;
}
