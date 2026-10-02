import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/domain_models.dart';

abstract interface class ReflectionRepository {
  Future<DailyReflection?> fetch(String userId, String date);
  Future<DailyReflection> save(String userId, String date, String wentWell, String carryForward);
}

class SupabaseReflectionRepository implements ReflectionRepository {
  SupabaseReflectionRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<DailyReflection?> fetch(String userId, String date) async {
    final row = await _client.from('daily_reflections').select().eq('user_id', userId).eq('date', date).maybeSingle();
    return row == null ? null : DailyReflection.fromDatabase(row);
  }

  @override
  Future<DailyReflection> save(String userId, String date, String wentWell, String carryForward) async {
    final row = await _client.from('daily_reflections').upsert(
      {'user_id': userId, 'date': date, 'went_well': wentWell, 'carry_forward': carryForward, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      onConflict: 'user_id,date',
    ).select().single();
    return DailyReflection.fromDatabase(row);
  }
}
