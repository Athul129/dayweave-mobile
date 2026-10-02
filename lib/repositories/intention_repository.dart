import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/domain_models.dart';

abstract interface class IntentionRepository {
  Future<DailyIntention?> fetch(String userId, String date);
  Future<void> save(String userId, String date, String intention);
}

class SupabaseIntentionRepository implements IntentionRepository {
  SupabaseIntentionRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<DailyIntention?> fetch(String userId, String date) async {
    final row = await _client.from('daily_intentions').select().eq('user_id', userId).eq('date', date).maybeSingle();
    return row == null ? null : DailyIntention.fromDatabase(row);
  }

  @override
  Future<void> save(String userId, String date, String intention) async {
    await _client.from('daily_intentions').upsert(
      {'user_id': userId, 'date': date, 'intention': intention, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      onConflict: 'user_id,date',
    );
  }
}
