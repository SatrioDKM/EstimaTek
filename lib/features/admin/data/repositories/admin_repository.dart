import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepository {
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  AdminRepository();

  // Fetch all users with optional email search query
  Future<List<Map<String, dynamic>>> fetchUsers({String? searchQuery}) async {
    try {
      var query = _supabaseClient
          .from('users')
          .select('email, is_active, last_sync');

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.ilike('email', '%${searchQuery.trim()}%');
      }

      // Order alphabetically by email
      final List<dynamic> response = await query.order('email', ascending: true);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      developer.log('Error in fetchUsers: $e', name: 'AdminRepository');
      rethrow;
    }
  }

  // Toggle is_active status for a specific user
  Future<void> toggleUserStatus(String email, bool isActive) async {
    try {
      await _supabaseClient.from('users').update({
        'is_active': isActive,
        'last_sync': DateTime.now().toIso8601String(),
      }).eq('email', email);
    } catch (e) {
      developer.log('Error in toggleUserStatus: $e', name: 'AdminRepository');
      rethrow;
    }
  }
}
