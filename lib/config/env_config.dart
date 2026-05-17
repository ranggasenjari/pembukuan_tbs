// lib/config/env_config.dart
// Configuration for Supabase initialization
// These values should be set via --dart-define during build/run

class SupabaseConfig {
  /// Get Supabase URL from environment or throw error
  static String get supabaseUrl {
    const url = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://supabase.langkatkab.go.id',
    );
    if (url.isEmpty || url == 'https://supabase.langkatkab.go.id') {
      throw Exception(
        'SUPABASE_URL not configured. '
        'Set via: flutter run --dart-define=SUPABASE_URL=your_url',
      );
    }
    return url;
  }

  /// Get Supabase Anon Key from environment or throw error
  static String get supabaseAnonKey {
    const key = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    if (key.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY not configured. '
        'Set via: flutter run --dart-define=SUPABASE_ANON_KEY=your_key',
      );
    }
    return key;
  }

  /// Get Supabase schema (defaults to 'inv')
  static String get supabaseSchema {
    const schema = String.fromEnvironment(
      'SUPABASE_SCHEMA',
      defaultValue: 'inv',
    );
    return schema;
  }
}
