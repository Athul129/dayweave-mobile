import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task.dart';

abstract interface class TaskRepository {
  Future<List<Task>> fetchForUser(String userId);
  Future<Task> create(String userId, Map<String, dynamic> draft);
  Future<Task> update(String userId, String id, Map<String, dynamic> changes);
  Future<void> delete(String userId, String id);
}

class SupabaseTaskRepository implements TaskRepository {
  SupabaseTaskRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Task>> fetchForUser(String userId) async {
    final rows = await _client.from('tasks').select().eq('user_id', userId).order('date').order('time');
    return rows.map((row) => Task.fromDatabase(row)).toList(growable: false);
  }

  @override
  Future<Task> create(String userId, Map<String, dynamic> draft) async {
    final row = await _client.from('tasks').insert({...draft, 'user_id': userId}).select().single();
    return Task.fromDatabase(row);
  }

  @override
  Future<Task> update(String userId, String id, Map<String, dynamic> changes) async {
    final row = await _client.from('tasks').update(changes).eq('id', id).eq('user_id', userId).select().single();
    return Task.fromDatabase(row);
  }

  @override
  Future<void> delete(String userId, String id) async {
    await _client.from('tasks').delete().eq('id', id).eq('user_id', userId);
  }
}
