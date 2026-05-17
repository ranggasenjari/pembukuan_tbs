import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient client;

  SupabaseService(this.client);

  // Example generic method helper, though we might use typed repositories
  Future<List<Map<String, dynamic>>> getAll(String table) async {
    return await client.from(table).select();
  }

  // Future helper methods for specific queries if shared across repos
}
