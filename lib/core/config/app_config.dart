class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabasePublishableKey});

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    return const AppConfig(supabaseUrl: url, supabasePublishableKey: key);
  }

  final String supabaseUrl;
  final String supabasePublishableKey;

  bool get isSupabaseConfigured => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  void validate() {
    if (!isSupabaseConfigured) {
      throw StateError(
        'Supabase is not configured. Provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY with dart-define.',
      );
    }
    if (!supabaseUrl.startsWith('https://')) {
      throw StateError('SUPABASE_URL must use HTTPS.');
    }
  }
}
