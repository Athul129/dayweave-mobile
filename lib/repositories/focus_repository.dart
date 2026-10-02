import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/domain_models.dart';

abstract interface class FocusRepository {
  Future<List<FocusSession>> fetchForUser(String userId);
  Future<FocusSession> saveCompleted(String userId, Map<String, dynamic> draft);
}

class SupabaseFocusRepository implements FocusRepository {
  SupabaseFocusRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<FocusSession>> fetchForUser(String userId) async {
    final rows = await _client.from('focus_sessions').select().eq('user_id', userId).order('completed_at', ascending: false);
    return rows.map((row) => FocusSession.fromDatabase(row)).toList(growable: false);
  }

  @override
  Future<FocusSession> saveCompleted(String userId, Map<String, dynamic> draft) async {
    final row = await _client.from('focus_sessions').upsert({...draft, 'user_id': userId}, onConflict: 'session_id').select().single();
    return FocusSession.fromDatabase(row);
  }
}
