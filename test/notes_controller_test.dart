import 'dart:async';
import 'dart:typed_data';

import 'package:dayweave_mobile/core/date_time/dayweave_date_time.dart';
import 'package:dayweave_mobile/features/auth/application/current_user_provider.dart';
import 'package:dayweave_mobile/features/notes/application/notes_controller.dart';
import 'package:dayweave_mobile/features/notes/presentation/loose_notes_screen.dart';
import 'package:dayweave_mobile/models/domain_models.dart';
import 'package:dayweave_mobile/models/note_attachment.dart';
import 'package:dayweave_mobile/repositories/note_attachment_repository.dart';
import 'package:dayweave_mobile/repositories/note_repository.dart';
import 'package:dayweave_mobile/services/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _testUserIdProvider = StateProvider<String?>((ref) => 'user-1');

class _FakeNoteRepository implements NoteRepository {
  final Map<String, List<Note>> notesByUser = {};
  final Map<String, Completer<List<Note>>> pendingFetches = {};
  final List<String> fetchedUsers = [];
  final List<(String, String, String)> creates = [];
  final List<(String, String, String, String)> updates = [];
  final List<(String, String)> deletes = [];
  final List<String> events = [];
  Object? fetchError;
  Object? createError;
  Object? updateError;
  Object? deleteError;
  Completer<Note>? pendingCreate;
  int _nextId = 1;
  int _timestamp = 1;

  @override
  Future<List<Note>> fetchForUser(String userId) {
    fetchedUsers.add(userId);
    final pending = pendingFetches[userId];
    if (pending != null) return pending.future;
    if (fetchError case final error?) return Future.error(error);
    return Future.value(List.of(notesByUser[userId] ?? const []));
  }

  @override
  Future<Note> create(String userId, String title, String body) async {
    creates.add((userId, title, body));
    if (createError case final error?) throw error;
    if (pendingCreate case final pending?) return pending.future;
    final note = _note('note-${_nextId++}', userId, title, body, _tick());
    notesByUser.putIfAbsent(userId, () => []).add(note);
    return note;
  }

  @override
  Future<Note> update(
    String userId,
    String id,
    String title,
    String body,
  ) async {
    updates.add((userId, id, title, body));
    if (updateError case final error?) throw error;
    final updated = _note(id, userId, title, body, _tick());
    final userNotes = notesByUser.putIfAbsent(userId, () => []);
    final index = userNotes.indexWhere((note) => note.id == id);
    if (index >= 0) userNotes[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String userId, String id) async {
    deletes.add((userId, id));
    events.add('delete-note:$id');
    if (deleteError case final error?) throw error;
    notesByUser[userId]?.removeWhere((note) => note.id == id);
  }

  DateTime _tick() => DateTime.utc(2026, 10, 1).add(
        Duration(seconds: _timestamp++),
      );
}

class _FakeNoteAttachmentRepository implements NoteAttachmentRepository {
  final List<NoteAttachment> attachments = [];
  final List<(String, String)> fetchedFor = [];
  final List<String> deletedIds = [];
  final Map<String, Object> deleteErrors = {};
  final Map<String, Completer<void>> pendingDeletes = {};
  List<String> events = [];
  Completer<List<NoteAttachment>>? pendingFetch;
  Object? fetchError;

  @override
  Future<List<NoteAttachment>> fetchForNote({
    required String userId,
    required String noteId,
  }) =>
      _fetchAttachments(userId: userId, noteId: noteId);

  @override
  Future<List<NoteAttachment>> fetchMetadataForNote({
    required String userId,
    required String noteId,
  }) =>
      _fetchAttachments(userId: userId, noteId: noteId);

  Future<List<NoteAttachment>> _fetchAttachments({
    required String userId,
    required String noteId,
  }) async {
    events.add('fetch-attachments:$userId:$noteId');
    fetchedFor.add((userId, noteId));
    final pending = pendingFetch;
    if (pending != null) return pending.future;
    if (fetchError case final error?) throw error;
    return attachments
        .where(
          (attachment) =>
              attachment.userId == userId && attachment.noteId == noteId,
        )
        .toList();
  }

  @override
  Future<void> deleteAttachment({
    required String userId,
    required NoteAttachment attachment,
  }) async {
    events.add('delete-attachment-start:${attachment.id}');
    final pending = pendingDeletes[attachment.id];
    if (pending != null) await pending.future;
    if (deleteErrors[attachment.id] case final error?) throw error;
    deletedIds.add(attachment.id);
    attachments.removeWhere((item) => item.id == attachment.id);
    events.add('delete-attachment-done:${attachment.id}');
  }

  @override
  Future<NoteAttachment> uploadPreparedMedia({
    required String userId,
    required String noteId,
    required Uint8List bytes,
    required NoteAttachmentMediaType mediaType,
    required String mimeType,
    required String extension,
    int? durationSeconds,
  }) =>
      throw UnimplementedError();
}

Note _note(
  String id,
  String userId,
  String title,
  String body,
  DateTime updatedAt,
) =>
    Note(
      id: id,
      userId: userId,
      title: title,
      body: body,
      createdAt: DayweaveTimestamp(DateTime.utc(2026, 9, 1)),
      updatedAt: DayweaveTimestamp(updatedAt),
    );

ProviderContainer _container(
  _FakeNoteRepository repository, {
  _FakeNoteAttachmentRepository? attachmentRepository,
  String? userId = 'user-1',
}) =>
    ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
        noteAttachmentRepositoryProvider.overrideWithValue(
          attachmentRepository ?? _FakeNoteAttachmentRepository(),
        ),
        currentUserIdProvider.overrideWith((ref) => userId),
      ],
    );

NoteAttachment _attachment(String id, {String noteId = 'existing'}) =>
    NoteAttachment(
      id: id,
      noteId: noteId,
      userId: 'user-1',
      storagePath: 'user-1/$noteId/$id.jpg',
      mediaType: NoteAttachmentMediaType.image,
      mimeType: 'image/jpeg',
      fileSize: 10,
      durationSeconds: null,
      createdAt: null,
    );

void main() {
  test('loads user-scoped notes newest first and exposes loading', () async {
    final repository = _FakeNoteRepository()
      ..notesByUser['user-1'] = [
        _note('older', 'user-1', 'Older', '', DateTime.utc(2026, 1, 1)),
        _note('newer', 'user-1', 'Newer', '', DateTime.utc(2026, 1, 2)),
      ]
      ..pendingFetches['user-1'] = Completer<List<Note>>();
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);

    final load = controller.load();
    expect(container.read(notesProvider).isLoading, isTrue);
    expect(repository.fetchedUsers, ['user-1']);
    repository.pendingFetches['user-1']!
        .complete(repository.notesByUser['user-1']);
    await load;

    expect(container.read(notesProvider).notes.map((note) => note.id), [
      'newer',
      'older',
    ]);
    expect(container.read(notesProvider).isLoading, isFalse);
    expect(container.read(notesProvider).loadError, isNull);
  });

  test('empty results are a successful empty state', () async {
    final repository = _FakeNoteRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    await container.read(notesProvider.notifier).load();

    expect(container.read(notesProvider).notes, isEmpty);
    expect(container.read(notesProvider).loadError, isNull);
    expect(container.read(notesProvider).isLoading, isFalse);
  });

  test('search matches title and body case-insensitively', () async {
    final repository = _FakeNoteRepository()
      ..notesByUser['user-1'] = [
        _note('title', 'user-1', 'Quiet Walk', '', DateTime.utc(2026, 1, 2)),
        _note('body', 'user-1', 'Loose thought', 'A QUIET place',
            DateTime.utc(2026, 1, 1)),
      ];
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);
    await controller.load();

    controller.setSearchQuery('  QUIET ');
    expect(container.read(notesProvider).filteredNotes.map((note) => note.id), [
      'title',
      'body',
    ]);
    controller.setSearchQuery('place');
    expect(container.read(notesProvider).filteredNotes.single.id, 'body');
    controller.setSearchQuery('missing');
    expect(container.read(notesProvider).hasNoMatches, isTrue);
  });

  test('creates, updates, and deletes with authenticated user and trimmed text',
      () async {
    final repository = _FakeNoteRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);
    await controller.load();

    final created = await controller.createNote(
      title: '  First note  ',
      body: '  Body text  ',
    );
    expect(repository.creates, [('user-1', 'First note', 'Body text')]);
    expect(container.read(notesProvider).notes.single.id, created.id);

    final updated = await controller.updateNote(
      created.id,
      title: '  Edited note ',
      body: ' Updated body  ',
    );
    expect(repository.updates, [
      ('user-1', created.id, 'Edited note', 'Updated body'),
    ]);
    expect(container.read(notesProvider).notes.single, updated);

    await controller.deleteNote(updated.id);
    expect(repository.deletes, [('user-1', updated.id)]);
    expect(container.read(notesProvider).notes, isEmpty);
    expect(container.read(notesProvider).isMutating, isFalse);
  });

  test('deletes a note with no attachments after the empty cleanup check',
      () async {
    final existing = _note(
      'existing',
      'user-1',
      'Keep this',
      '',
      DateTime.utc(2026, 1, 1),
    );
    final repository = _FakeNoteRepository()
      ..notesByUser['user-1'] = [existing];
    final attachments = _FakeNoteAttachmentRepository()
      ..events = repository.events;
    final container = _container(repository, attachmentRepository: attachments);
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);
    await controller.load();

    await controller.deleteNote(existing.id);

    expect(attachments.fetchedFor, [('user-1', existing.id)]);
    expect(repository.events, [
      'fetch-attachments:user-1:existing',
      'delete-note:existing',
    ]);
    expect(repository.deletes, [('user-1', existing.id)]);
    expect(container.read(notesProvider).notes, isEmpty);
  });

  test('cleans multiple attachments sequentially before deleting the note',
      () async {
    final existing = _note(
      'existing',
      'user-1',
      'With media',
      '',
      DateTime.utc(2026, 1, 1),
    );
    final repository = _FakeNoteRepository()
      ..notesByUser['user-1'] = [existing];
    final attachments = _FakeNoteAttachmentRepository()
      ..events = repository.events
      ..attachments.addAll([
        _attachment('first'),
        _attachment('second'),
      ]);
    final container = _container(repository, attachmentRepository: attachments);
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);
    await controller.load();

    await controller.deleteNote(existing.id);

    expect(repository.events, [
      'fetch-attachments:user-1:existing',
      'delete-attachment-start:first',
      'delete-attachment-done:first',
      'delete-attachment-start:second',
      'delete-attachment-done:second',
      'delete-note:existing',
    ]);
    expect(repository.deletes, [('user-1', existing.id)]);
    expect(container.read(notesProvider).notes, isEmpty);
  });

  test('attachment cleanup failure retains note and does not delete its row',
      () async {
    final existing = _note(
      'existing',
      'user-1',
      'Keep this',
      '',
      DateTime.utc(2026, 1, 1),
    );
    final repository = _FakeNoteRepository()
      ..notesByUser['user-1'] = [existing];
    final attachments = _FakeNoteAttachmentRepository()
      ..events = repository.events
      ..attachments.add(_attachment('blocked'))
      ..deleteErrors['blocked'] = StateError('storage denied');
    final container = _container(repository, attachmentRepository: attachments);
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);
    await controller.load();

    await expectLater(
      controller.deleteNote(existing.id),
      throwsA(
        isA<NoteDeletionFailure>().having(
          (error) => error.stage,
          'stage',
          NoteDeletionStage.removeAttachment,
        ),
      ),
    );

    expect(repository.deletes, isEmpty);
    expect(container.read(notesProvider).notes.single, existing);
    expect(container.read(notesProvider).mutationError,
        isA<NoteDeletionFailure>());
    expect(container.read(notesProvider).isMutating, isFalse);
  });

  test('note deletion failure retains note and retry finishes after cleanup',
      () async {
    final existing = _note(
      'existing',
      'user-1',
      'Retry this',
      '',
      DateTime.utc(2026, 1, 1),
    );
    final repository = _FakeNoteRepository()
      ..notesByUser['user-1'] = [existing]
      ..deleteError = StateError('database unavailable');
    final attachments = _FakeNoteAttachmentRepository()
      ..events = repository.events
      ..attachments.add(_attachment('only'));
    final container = _container(repository, attachmentRepository: attachments);
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);
    await controller.load();

    await expectLater(
      controller.deleteNote(existing.id),
      throwsA(
        isA<NoteDeletionFailure>().having(
          (error) => error.stage,
          'stage',
          NoteDeletionStage.deleteNote,
        ),
      ),
    );
    expect(container.read(notesProvider).notes.single, existing);
    expect(attachments.attachments, isEmpty);

    repository.deleteError = null;
    await controller.deleteNote(existing.id);

    expect(repository.deletes, [
      ('user-1', existing.id),
      ('user-1', existing.id),
    ]);
    expect(container.read(notesProvider).notes, isEmpty);
  });

  test('retry after partial attachment cleanup processes only remaining media',
      () async {
    final existing = _note(
      'existing',
      'user-1',
      'Retry attachments',
      '',
      DateTime.utc(2026, 1, 1),
    );
    final repository = _FakeNoteRepository()
      ..notesByUser['user-1'] = [existing];
    final attachments = _FakeNoteAttachmentRepository()
      ..events = repository.events
      ..attachments.addAll([_attachment('first'), _attachment('second')])
      ..deleteErrors['second'] = StateError('temporary storage failure');
    final container = _container(repository, attachmentRepository: attachments);
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);
    await controller.load();

    await expectLater(
      controller.deleteNote(existing.id),
      throwsA(isA<NoteDeletionFailure>()),
    );
    expect(container.read(notesProvider).notes.single, existing);
    expect(attachments.attachments.map((item) => item.id), ['second']);

    attachments.deleteErrors.clear();
    await controller.deleteNote(existing.id);

    expect(attachments.deletedIds, ['first', 'second']);
    expect(attachments.fetchedFor, [
      ('user-1', existing.id),
      ('user-1', existing.id),
    ]);
    expect(repository.deletes, [('user-1', existing.id)]);
    expect(container.read(notesProvider).notes, isEmpty);
  });

  test('account change during cleanup stops before deleting note row',
      () async {
    final repository = _FakeNoteRepository()
      ..notesByUser['user-1'] = [
        _note(
          'existing',
          'user-1',
          'Old account note',
          '',
          DateTime.utc(2026, 1, 1),
        ),
      ];
    final attachments = _FakeNoteAttachmentRepository();
    final users = StateProvider<String?>((ref) => 'user-1');
    final container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
        noteAttachmentRepositoryProvider.overrideWithValue(attachments),
        currentUserIdProvider.overrideWith((ref) => ref.watch(users)),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);
    await controller.load();
    final pendingFetch = Completer<List<NoteAttachment>>();
    attachments.pendingFetch = pendingFetch;

    final deletion = controller.deleteNote('existing');
    container.read(users.notifier).state = 'user-2';
    expect(container.read(currentUserIdProvider), 'user-2');
    pendingFetch.complete([_attachment('old-user-attachment')]);

    await expectLater(deletion, throwsStateError);
    expect(attachments.fetchedFor, [('user-1', 'existing')]);
    expect(repository.deletes, isEmpty);
    expect(attachments.deletedIds, isEmpty);
    expect(container.read(notesProvider).userId, 'user-2');
    expect(container.read(notesProvider).notes, isEmpty);
  });

  test('duplicate concurrent note deletion is rejected', () async {
    final repository = _FakeNoteRepository()
      ..notesByUser['user-1'] = [
        _note(
          'existing',
          'user-1',
          'Only delete once',
          '',
          DateTime.utc(2026, 1, 1),
        ),
      ];
    final attachments = _FakeNoteAttachmentRepository()
      ..pendingFetch = Completer<List<NoteAttachment>>();
    final container = _container(repository, attachmentRepository: attachments);
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);
    await controller.load();

    final firstDelete = controller.deleteNote('existing');
    await expectLater(
      controller.deleteNote('existing'),
      throwsStateError,
    );
    attachments.pendingFetch!.complete([]);
    await firstDelete;

    expect(repository.deletes, [('user-1', 'existing')]);
  });

  test('load and mutation failures are recoverable and retain note data',
      () async {
    final existing = _note(
      'existing',
      'user-1',
      'Keep this',
      '',
      DateTime.utc(2026, 1, 1),
    );
    final repository = _FakeNoteRepository()
      ..notesByUser['user-1'] = [existing]
      ..fetchError = StateError('fetch failed');
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);

    await controller.load();
    expect(container.read(notesProvider).loadError, isA<StateError>());
    expect(container.read(notesProvider).isLoading, isFalse);
    repository.fetchError = null;
    await controller.load();
    expect(container.read(notesProvider).notes.single.id, 'existing');
    expect(container.read(notesProvider).loadError, isNull);

    repository.updateError = StateError('update failed');
    await expectLater(
      controller.updateNote(existing.id, title: 'Changed', body: ''),
      throwsA(isA<StateError>()),
    );
    expect(container.read(notesProvider).notes.single, existing);
    expect(container.read(notesProvider).mutationError, isA<StateError>());
    expect(container.read(notesProvider).isMutating, isFalse);

    repository.deleteError = StateError('delete failed');
    await expectLater(
      controller.deleteNote(existing.id),
      throwsA(
        isA<NoteDeletionFailure>()
            .having(
              (error) => error.stage,
              'stage',
              NoteDeletionStage.deleteNote,
            )
            .having(
              (error) => error.cause,
              'cause',
              isA<StateError>(),
            ),
      ),
    );
    expect(container.read(notesProvider).notes.single, existing);
    expect(
      container.read(notesProvider).mutationError,
      isA<NoteDeletionFailure>(),
    );
  });

  test('rejects blank titles and duplicate concurrent mutations', () async {
    final repository = _FakeNoteRepository()..pendingCreate = Completer<Note>();
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);
    await controller.load();

    await expectLater(
      controller.createNote(title: '  ', body: 'Only body'),
      throwsArgumentError,
    );
    final create = controller.createNote(title: 'Valid', body: 'Body');
    expect(container.read(notesProvider).isMutating, isTrue);
    await expectLater(
      controller.createNote(title: 'Duplicate', body: ''),
      throwsStateError,
    );
    repository.pendingCreate!.complete(
      _note('created', 'user-1', 'Valid', 'Body', DateTime.utc(2026, 1, 1)),
    );
    await create;
    expect(repository.creates, [('user-1', 'Valid', 'Body')]);
    expect(container.read(notesProvider).isMutating, isFalse);
  });

  test('stale load from a previous authenticated user is ignored', () async {
    final repository = _FakeNoteRepository()
      ..pendingFetches['user-1'] = Completer<List<Note>>();
    final container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
        noteAttachmentRepositoryProvider.overrideWithValue(
          _FakeNoteAttachmentRepository(),
        ),
        currentUserIdProvider.overrideWith(
          (ref) => ref.watch(_testUserIdProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);

    final oldLoad = controller.load();
    container.read(_testUserIdProvider.notifier).state = 'user-2';
    expect(container.read(notesProvider).userId, 'user-2');
    final newLoad = controller.load();
    await newLoad;
    expect(container.read(notesProvider).notes, isEmpty);

    repository.pendingFetches['user-1']!.complete([
      _note('old', 'user-1', 'Old account note', '', DateTime.utc(2026, 1, 1)),
    ]);
    await oldLoad;
    expect(container.read(notesProvider).userId, 'user-2');
    expect(container.read(notesProvider).notes, isEmpty);
    expect(repository.fetchedUsers, ['user-1', 'user-2']);
  });

  test('stale mutation response cannot update the next user state', () async {
    final repository = _FakeNoteRepository()..pendingCreate = Completer<Note>();
    final container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
        noteAttachmentRepositoryProvider.overrideWithValue(
          _FakeNoteAttachmentRepository(),
        ),
        currentUserIdProvider.overrideWith(
          (ref) => ref.watch(_testUserIdProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);
    await controller.load();

    final create = controller.createNote(title: 'Old user note', body: '');
    container.read(_testUserIdProvider.notifier).state = 'user-2';
    expect(container.read(notesProvider).userId, 'user-2');
    await container.read(notesProvider.notifier).load();

    repository.pendingCreate!.complete(
      _note(
        'old-user-note',
        'user-1',
        'Old user note',
        '',
        DateTime.utc(2026, 1, 1),
      ),
    );
    await create;

    expect(container.read(notesProvider).userId, 'user-2');
    expect(container.read(notesProvider).notes, isEmpty);
  });

  testWidgets('screen shows load error, retries, and reaches empty state', (
    tester,
  ) async {
    final repository = _FakeNoteRepository()
      ..fetchError = StateError('offline');
    await tester.pumpWidget(_notesApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Your notes could not be loaded. Please try again.'),
        findsOneWidget);
    repository.fetchError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing loose yet.'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads the short list and preserves search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeNoteRepository();
    await tester.pumpWidget(_notesApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Nothing loose yet.'), findsOneWidget);
    expect(repository.fetchedUsers, ['user-1']);
    await tester.enterText(
        find.byKey(const Key('notes-search-field')), 'fresh');
    await tester.pump();

    final refreshResponse = Completer<List<Note>>();
    repository.pendingFetches['user-1'] = refreshResponse;
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 400),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.fetchedUsers, ['user-1', 'user-1']);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    refreshResponse.complete([
      _note(
        'fresh-note',
        'user-1',
        'Fresh note',
        'Loaded after refresh',
        DateTime.utc(2026, 10, 29),
      ),
    ]);
    repository.pendingFetches.remove('user-1');
    await tester.pumpAndSettle();

    expect(find.text('Fresh note'), findsOneWidget);
    expect(find.text('Loaded after refresh'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('notes-search-field')))
          .controller
          ?.text,
      'fresh',
    );
    expect(repository.fetchedUsers, ['user-1', 'user-1']);
  });

  testWidgets('screen creates, edits, searches, and confirms deletion', (
    tester,
  ) async {
    final repository = _FakeNoteRepository();
    await tester.pumpWidget(_notesApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('note-title-field')), 'A note');
    await tester.enterText(
        find.byKey(const Key('note-body-field')), 'Some body');
    await tester.ensureVisible(find.text('Save note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    expect(find.text('A note'), findsOneWidget);
    expect(find.text('Some body'), findsOneWidget);

    await tester.tap(find.text('Edit note'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('note-title-field')), 'Edited note');
    await tester.ensureVisible(find.text('Save note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    expect(find.text('Edited note'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('notes-search-field')), 'absent');
    await tester.pumpAndSettle();
    expect(find.text('No matching notes.'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('notes-search-field')), 'edited');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edited note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete note'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this note?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-note-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing loose yet.'), findsOneWidget);
    expect(find.text('Note deleted'), findsOneWidget);
  });

  testWidgets('failed attachment cleanup keeps note and shows retry guidance', (
    tester,
  ) async {
    final existing = _note(
      'existing',
      'user-1',
      'Keep my note',
      'Text remains safe.',
      DateTime.utc(2026, 1, 1),
    );
    final notes = _FakeNoteRepository()..notesByUser['user-1'] = [existing];
    final attachments = _FakeNoteAttachmentRepository()
      ..attachments.add(_attachment('blocked'))
      ..deleteErrors['blocked'] = StateError('permission denied');
    await tester.pumpWidget(
      _notesApp(notes, attachmentRepository: attachments),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep my note'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete note'));
    await tester.tap(find.text('Delete note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-note-delete')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'An attachment could not be removed. Your note is still here; retry deletion.',
      ),
      findsOneWidget,
    );
    expect(find.text('Delete this note?'), findsOneWidget);
    expect(find.text('Text remains safe.'), findsOneWidget);
    expect(notes.deletes, isEmpty);
  });
}

Widget _notesApp(
  _FakeNoteRepository repository, {
  _FakeNoteAttachmentRepository? attachmentRepository,
}) =>
    ProviderScope(
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
        noteAttachmentRepositoryProvider.overrideWithValue(
          attachmentRepository ?? _FakeNoteAttachmentRepository(),
        ),
        currentUserIdProvider.overrideWith((ref) => 'user-1'),
      ],
      child: const MaterialApp(
        home: Scaffold(body: LooseNotesScreen()),
      ),
    );
