// lib/config/env_config.dart
// Configuration for Supabase initialization
// Values can be set via --dart-define or local .env.

import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  /// Get Supabase URL from environment or throw error
  static String get supabaseUrl {
    const definedUrl = String.fromEnvironment('SUPABASE_URL');
    final url = definedUrl.isNotEmpty
        ? definedUrl
        : dotenv.env['SUPABASE_URL'] ?? 'https://supabase.langkatkab.go.id';
    if (url.isEmpty) {
      throw Exception(
        'SUPABASE_URL not configured. '
        'Set via .env or flutter run --dart-define=SUPABASE_URL=your_url',
      );
    }
    return url;
  }

  /// Get Supabase Anon Key from environment or throw error
  static String get supabaseAnonKey {
    const definedKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    final key = definedKey.isNotEmpty
        ? definedKey
        : dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    if (key.isEmpty || key == 'your-anon-key-here') {
      throw Exception(
        'SUPABASE_ANON_KEY not configured. '
        'Set via .env or flutter run --dart-define=SUPABASE_ANON_KEY=your_key',
      );
    }
    return key;
  }

  /// Get Supabase schema (defaults to 'inv')
  static String get supabaseSchema {
    const definedSchema = String.fromEnvironment('SUPABASE_SCHEMA');
    return definedSchema.isNotEmpty
        ? definedSchema
        : dotenv.env['SUPABASE_SCHEMA'] ?? 'inv';
  }
}
