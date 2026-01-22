import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    // 1. Read keys passed via --dart-define during build/run
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    // 2. Validate keys to prevent runtime crashes if forgotten
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception(
        'CRITICAL: Supabase keys not found. \n'
        'Make sure to run with: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...'
      );
    }

    // 3. Initialize Supabase
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}