import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/domain_models.dart';

abstract interface class NoteRepository {
  Future<List<Note>> fetchForUser(String userId);
  Future<Note> create(String userId, String title, String body);
  Future<Note> update(String userId, String id, String title, String body);
  Future<void> delete(String userId, String id);
}

class SupabaseNoteRepository implements NoteRepository {
  SupabaseNoteRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Note>> fetchForUser(String userId) async {
    final rows = await _client.from('notes').select().eq('user_id', userId).order('updated_at', ascending: false);
    return rows.map((row) => Note.fromDatabase(row)).toList(growable: false);
  }

  @override
  Future<Note> create(String userId, String title, String body) async {
    final row = await _client.from('notes').insert({'user_id': userId, 'title': title, 'body': body}).select().single();
    return Note.fromDatabase(row);
  }

  @override
  Future<Note> update(String userId, String id, String title, String body) async {
    final row = await _client.from('notes').update({'title': title, 'body': body, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id).eq('user_id', userId).select().single();
    return Note.fromDatabase(row);
  }

  @override
  Future<void> delete(String userId, String id) async {
    await _client.from('notes').delete().eq('id', id).eq('user_id', userId);
  }
}
