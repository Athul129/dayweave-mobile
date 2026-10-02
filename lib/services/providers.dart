import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/focus_repository.dart';
import '../repositories/intention_repository.dart';
import '../repositories/note_repository.dart';
import '../repositories/reflection_repository.dart';
import '../repositories/task_repository.dart';
import 'auth_service.dart';
import 'supabase_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) => SupabaseService.client());
final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.watch(supabaseClientProvider)));
final authStateProvider = StreamProvider<AuthState>((ref) => ref.watch(authServiceProvider).authStateChanges);
final taskRepositoryProvider = Provider<TaskRepository>((ref) => SupabaseTaskRepository(ref.watch(supabaseClientProvider)));
final noteRepositoryProvider = Provider<NoteRepository>((ref) => SupabaseNoteRepository(ref.watch(supabaseClientProvider)));
final intentionRepositoryProvider = Provider<IntentionRepository>((ref) => SupabaseIntentionRepository(ref.watch(supabaseClientProvider)));
final reflectionRepositoryProvider = Provider<ReflectionRepository>((ref) => SupabaseReflectionRepository(ref.watch(supabaseClientProvider)));
final focusRepositoryProvider = Provider<FocusRepository>((ref) => SupabaseFocusRepository(ref.watch(supabaseClientProvider)));
