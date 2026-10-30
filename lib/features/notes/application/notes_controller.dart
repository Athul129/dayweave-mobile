import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/application/current_user_provider.dart';
import '../../../models/domain_models.dart';
import '../../../models/note_attachment.dart';
import '../../../repositories/note_attachment_repository.dart';
import '../../../repositories/note_repository.dart';
import '../../../services/providers.dart';
import 'note_media_picker.dart';
import 'note_media_preparation.dart';

enum NoteDeletionStage { loadAttachments, removeAttachment, deleteNote }

class NoteDeletionFailure implements Exception {
  const NoteDeletionFailure(this.stage, this.cause);

  final NoteDeletionStage stage;
  final Object cause;

  String get userMessage => switch (stage) {
        NoteDeletionStage.loadAttachments =>
          'Attachments could not be checked. Your note is still here; try again.',
        NoteDeletionStage.removeAttachment =>
          'An attachment could not be removed. Your note is still here; retry deletion.',
        NoteDeletionStage.deleteNote =>
          'Attachments were removed, but the note was not deleted. Retry to finish.',
      };

  @override
  String toString() => 'Note deletion failed during $stage: $cause';
}

class NotesState {
  const NotesState({
    required this.userId,
    this.notes = const [],
    this.query = '',
    this.isLoading = false,
    this.isMutating = false,
    this.loadError,
    this.mutationError,
    this.attachmentsByNoteId = const {},
    this.attachmentLoadErrorsByNoteId = const {},
    this.attachmentLoadsInFlight = const {},
  });

  final String? userId;
  final List<Note> notes;
  final String query;
  final bool isLoading;
  final bool isMutating;
  final Object? loadError;
  final Object? mutationError;
  final Map<String, List<NoteAttachment>> attachmentsByNoteId;
  final Map<String, Object> attachmentLoadErrorsByNoteId;
  final Set<String> attachmentLoadsInFlight;

  List<Note> get filteredNotes {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return notes;
    return notes
        .where(
          (note) =>
              note.title.toLowerCase().contains(normalizedQuery) ||
              note.body.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
  }

  bool get hasNoMatches => notes.isNotEmpty && filteredNotes.isEmpty;

  NotesState copyWith({
    List<Note>? notes,
    String? query,
    bool? isLoading,
    bool? isMutating,
    Object? loadError,
    Object? mutationError,
    bool clearLoadError = false,
    bool clearMutationError = false,
    Map<String, List<NoteAttachment>>? attachmentsByNoteId,
    Map<String, Object>? attachmentLoadErrorsByNoteId,
    Set<String>? attachmentLoadsInFlight,
  }) =>
      NotesState(
        userId: userId,
        notes: notes ?? this.notes,
        query: query ?? this.query,
        isLoading: isLoading ?? this.isLoading,
        isMutating: isMutating ?? this.isMutating,
        loadError: clearLoadError ? null : loadError ?? this.loadError,
        mutationError:
            clearMutationError ? null : mutationError ?? this.mutationError,
        attachmentsByNoteId: attachmentsByNoteId ?? this.attachmentsByNoteId,
        attachmentLoadErrorsByNoteId:
            attachmentLoadErrorsByNoteId ?? this.attachmentLoadErrorsByNoteId,
        attachmentLoadsInFlight:
            attachmentLoadsInFlight ?? this.attachmentLoadsInFlight,
      );
}

final notesProvider = NotifierProvider<NotesController, NotesState>(
  NotesController.new,
);

class NotesController extends Notifier<NotesState> {
  late NoteRepository _repository;
  late NoteAttachmentRepository _attachmentRepository;
  late NoteMediaPicker _mediaPicker;
  late NoteMediaPreparationService _mediaPreparation;
  String? _activeUserId;
  int _userGeneration = 0;
  int _loadVersion = 0;
  bool _mutationInFlight = false;
  final Map<String, int> _attachmentLoadVersions = {};

  @override
  NotesState build() {
    _repository = ref.watch(noteRepositoryProvider);
    _attachmentRepository = ref.watch(noteAttachmentRepositoryProvider);
    _mediaPicker = ref.watch(noteMediaPickerProvider);
    _mediaPreparation = ref.watch(noteMediaPreparationProvider);
    final userId = ref.read(currentUserIdProvider);
    _activeUserId = userId;
    _userGeneration++;
    _loadVersion++;
    ref.listen<String?>(currentUserIdProvider, (_, nextUserId) {
      if (nextUserId == _activeUserId) return;
      _activeUserId = nextUserId;
      _userGeneration++;
      _loadVersion++;
      state = NotesState(userId: nextUserId, isLoading: nextUserId != null);
      _attachmentLoadVersions.clear();
    });
    return NotesState(userId: userId, isLoading: userId != null);
  }

  void setSearchQuery(String value) {
    state = state.copyWith(query: value);
  }

  Future<NoteMediaSelectionResult> pickAndPrepareMedia() async {
    final userId = _activeUserId;
    if (userId == null) throw StateError('Sign in to attach media.');
    final generation = _userGeneration;
    final selected = await _mediaPicker.pickMultiple();
    _ensureCurrentUser(userId, generation, operation: 'media selection');

    final prepared = <PreparedNoteMedia>[];
    final errors = <String>[];
    for (final file in selected) {
      _ensureCurrentUser(userId, generation, operation: 'media selection');
      try {
        final bytes = await file.readBytes();
        prepared.add(await _mediaPreparation.prepare(
          fileName: file.fileName,
          mimeType: file.mimeType,
          bytes: bytes,
        ));
      } catch (error) {
        errors.add('${file.fileName}: ${_mediaErrorMessage(error)}');
      }
    }
    _ensureCurrentUser(userId, generation, operation: 'media selection');
    return NoteMediaSelectionResult(prepared: prepared, errors: errors);
  }

  Future<void> loadAttachments(String noteId) async {
    final userId = _activeUserId;
    if (userId == null) return;
    if (state.attachmentLoadsInFlight.contains(noteId)) return;
    final generation = _userGeneration;
    final version = (_attachmentLoadVersions[noteId] ?? 0) + 1;
    _attachmentLoadVersions[noteId] = version;
    final errors = Map<String, Object>.of(state.attachmentLoadErrorsByNoteId)
      ..remove(noteId);
    state = state.copyWith(attachmentLoadErrorsByNoteId: errors);
    state = state.copyWith(
      attachmentLoadsInFlight: {...state.attachmentLoadsInFlight, noteId},
    );
    try {
      final attachments = await _attachmentRepository.fetchForNote(
        userId: userId,
        noteId: noteId,
      );
      if (!_isCurrent(userId, generation) ||
          _attachmentLoadVersions[noteId] != version) {
        return;
      }
      state = state.copyWith(
        attachmentsByNoteId: {
          ...state.attachmentsByNoteId,
          noteId: List.unmodifiable(attachments),
        },
        attachmentLoadsInFlight: {
          ...state.attachmentLoadsInFlight.where((id) => id != noteId),
        },
      );
    } catch (error) {
      if (!_isCurrent(userId, generation) ||
          _attachmentLoadVersions[noteId] != version) {
        return;
      }
      state = state.copyWith(
        attachmentLoadErrorsByNoteId: {
          ...state.attachmentLoadErrorsByNoteId,
          noteId: error,
        },
        attachmentLoadsInFlight: {
          ...state.attachmentLoadsInFlight.where((id) => id != noteId),
        },
      );
    }
  }

  Future<NoteAttachment> uploadPreparedMedia({
    required String noteId,
    required PreparedNoteMedia media,
  }) async {
    final (userId, generation) = _beginMutation();
    try {
      Note? note;
      for (final item in state.notes) {
        if (item.id == noteId) {
          note = item;
          break;
        }
      }
      if (note == null || note.userId != userId) {
        throw StateError('This note is no longer available for this account.');
      }
      final duration = media.durationSeconds?.ceil();
      final uploaded = await _attachmentRepository.uploadPreparedMedia(
        userId: userId,
        noteId: noteId,
        bytes: media.bytes,
        mediaType: media.mediaType,
        mimeType: media.mimeType,
        extension: media.extension,
        durationSeconds: duration,
      );
      _ensureCurrentUser(userId, generation, operation: 'media upload');
      final existing = state.attachmentsByNoteId[noteId] ?? const [];
      state = state.copyWith(
        attachmentsByNoteId: {
          ...state.attachmentsByNoteId,
          noteId: List.unmodifiable([
            ...existing.where((item) => item.id != uploaded.id),
            uploaded,
          ]),
        },
      );
      return uploaded;
    } catch (error) {
      if (_isCurrent(userId, generation)) {
        state = state.copyWith(mutationError: error);
      }
      rethrow;
    } finally {
      _endMutation(userId, generation);
    }
  }

  Future<void> deleteAttachment({
    required String noteId,
    required NoteAttachment attachment,
  }) async {
    final (userId, generation) = _beginMutation();
    try {
      if (attachment.noteId != noteId || attachment.userId != userId) {
        throw StateError('The attachment does not belong to this note.');
      }
      _ensureCurrentUser(userId, generation, operation: 'attachment removal');
      await _attachmentRepository.deleteAttachment(
        userId: userId,
        attachment: attachment,
      );
      _ensureCurrentUser(userId, generation, operation: 'attachment removal');
      final remaining = (state.attachmentsByNoteId[noteId] ?? const [])
          .where((item) => item.id != attachment.id)
          .toList(growable: false);
      state = state.copyWith(
        attachmentsByNoteId: {
          ...state.attachmentsByNoteId,
          noteId: List.unmodifiable(remaining),
        },
        clearMutationError: true,
      );
    } catch (error) {
      if (_isCurrent(userId, generation)) {
        state = state.copyWith(mutationError: error);
      }
      rethrow;
    } finally {
      _endMutation(userId, generation);
    }
  }

  Future<void> load() async {
    final userId = _activeUserId;
    final generation = _userGeneration;
    final version = ++_loadVersion;
    if (userId == null) {
      state = NotesState(userId: null, query: state.query);
      return;
    }

    state = state.copyWith(isLoading: true, clearLoadError: true);
    try {
      final notes = await _repository.fetchForUser(userId);
      if (!_isCurrent(userId, generation) || version != _loadVersion) return;
      state = state.copyWith(
        notes: _sortNewestFirst(notes),
        isLoading: false,
        clearLoadError: true,
      );
    } catch (error) {
      if (!_isCurrent(userId, generation) || version != _loadVersion) return;
      state = state.copyWith(isLoading: false, loadError: error);
    }
  }

  Future<Note> createNote({required String title, required String body}) async {
    final normalized = _normalize(title, body);
    final (userId, generation) = _beginMutation();
    try {
      final created = await _repository.create(
        userId,
        normalized.$1,
        normalized.$2,
      );
      if (_isCurrent(userId, generation)) {
        state = state.copyWith(
          notes: _sortNewestFirst([...state.notes, created]),
        );
      }
      return created;
    } catch (error) {
      if (_isCurrent(userId, generation)) {
        state = state.copyWith(mutationError: error);
      }
      rethrow;
    } finally {
      _endMutation(userId, generation);
    }
  }

  Future<Note> updateNote(
    String id, {
    required String title,
    required String body,
  }) async {
    final normalized = _normalize(title, body);
    final (userId, generation) = _beginMutation();
    try {
      final updated = await _repository.update(
        userId,
        id,
        normalized.$1,
        normalized.$2,
      );
      if (_isCurrent(userId, generation)) {
        state = state.copyWith(
          notes: _sortNewestFirst([
            for (final note in state.notes)
              if (note.id == id) updated else note,
          ]),
        );
      }
      return updated;
    } catch (error) {
      if (_isCurrent(userId, generation)) {
        state = state.copyWith(mutationError: error);
      }
      rethrow;
    } finally {
      _endMutation(userId, generation);
    }
  }

  Future<void> deleteNote(String id) async {
    final (userId, generation) = _beginMutation();
    try {
      late final List<NoteAttachment> attachments;
      try {
        attachments = await _attachmentRepository.fetchMetadataForNote(
          userId: userId,
          noteId: id,
        );
      } catch (error) {
        throw NoteDeletionFailure(NoteDeletionStage.loadAttachments, error);
      }
      _ensureCurrentUser(userId, generation);

      for (final attachment in attachments) {
        _ensureCurrentUser(userId, generation);
        if (attachment.userId != userId || attachment.noteId != id) {
          throw NoteDeletionFailure(
            NoteDeletionStage.removeAttachment,
            StateError('The attachment is not owned by this note.'),
          );
        }
        try {
          await _attachmentRepository.deleteAttachment(
            userId: userId,
            attachment: attachment,
          );
        } catch (error) {
          throw NoteDeletionFailure(
            NoteDeletionStage.removeAttachment,
            error,
          );
        }
        _ensureCurrentUser(userId, generation);
      }

      _ensureCurrentUser(userId, generation);
      try {
        await _repository.delete(userId, id);
      } catch (error) {
        throw NoteDeletionFailure(NoteDeletionStage.deleteNote, error);
      }

      if (_isCurrent(userId, generation)) {
        state = state.copyWith(
          notes: state.notes.where((note) => note.id != id).toList(),
        );
      }
    } catch (error) {
      if (_isCurrent(userId, generation)) {
        state = state.copyWith(mutationError: error);
      }
      rethrow;
    } finally {
      _endMutation(userId, generation);
    }
  }

  (String, int) _beginMutation() {
    final userId = _activeUserId;
    if (userId == null) throw StateError('Sign in to save notes.');
    if (state.isLoading) {
      throw StateError('Wait for your notes to finish loading.');
    }
    if (_mutationInFlight) {
      throw StateError('A note change is already in progress.');
    }
    _mutationInFlight = true;
    final generation = _userGeneration;
    _loadVersion++;
    state = state.copyWith(
      isLoading: false,
      isMutating: true,
      clearMutationError: true,
    );
    return (userId, generation);
  }

  void _endMutation(String userId, int generation) {
    _mutationInFlight = false;
    if (_isCurrent(userId, generation)) {
      state = state.copyWith(isMutating: false);
    }
  }

  bool _isCurrent(String userId, int generation) =>
      generation == _userGeneration &&
      _activeUserId == userId &&
      ref.read(currentUserIdProvider) == userId;

  void _ensureCurrentUser(
    String userId,
    int generation, {
    String operation = 'note deletion',
  }) {
    if (!_isCurrent(userId, generation)) {
      throw StateError('The signed-in account changed during $operation.');
    }
  }

  (String, String) _normalize(String title, String body) {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Give this note a title before saving.');
    }
    return (normalizedTitle, body.trim());
  }

  List<Note> _sortNewestFirst(Iterable<Note> notes) {
    final sorted = notes.toList();
    sorted.sort(
      (left, right) => right.updatedAt.value.compareTo(left.updatedAt.value),
    );
    return List.unmodifiable(sorted);
  }

  String _mediaErrorMessage(Object error) =>
      error is NoteMediaPreparationException
          ? error.message
          : error is FormatException
              ? error.message
              : 'This file could not be prepared.';
}

class NoteMediaSelectionResult {
  const NoteMediaSelectionResult(
      {required this.prepared, required this.errors});

  final List<PreparedNoteMedia> prepared;
  final List<String> errors;
}
