import 'dart:async';
import 'dart:typed_data';

import 'package:dayweave_mobile/core/date_time/dayweave_date_time.dart';
import 'package:dayweave_mobile/features/auth/application/current_user_provider.dart';
import 'package:dayweave_mobile/features/notes/application/note_media_picker.dart';
import 'package:dayweave_mobile/features/notes/application/note_media_preparation.dart';
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

final _userProvider = StateProvider<String?>((ref) => 'user-1');

class _Picker implements NoteMediaPicker {
  _Picker(this.files);

  List<PickedNoteMedia> files;
  int calls = 0;

  @override
  Future<List<PickedNoteMedia>> pickMultiple() async {
    calls++;
    return files;
  }
}

class _Preparation implements NoteMediaPreparationService {
  final List<String> preparedNames = [];
  final Set<String> unsupportedNames = {};

  @override
  Future<PreparedNoteMedia> prepare({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    preparedNames.add(fileName);
    if (unsupportedNames.contains(fileName) ||
        !{'image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/webm'}
            .contains(mimeType)) {
      throw const NoteMediaPreparationException(
        'Use JPG, PNG, WebP, MP4, or WebM files.',
      );
    }
    final video = mimeType.startsWith('video/');
    return PreparedNoteMedia(
      fileName: fileName,
      bytes: bytes,
      mediaType:
          video ? NoteAttachmentMediaType.video : NoteAttachmentMediaType.image,
      mimeType: mimeType,
      extension: fileName.split('.').last,
      durationSeconds: video ? 9.2 : null,
    );
  }
}

class _Notes implements NoteRepository {
  final Map<String, List<Note>> byUser = {};
  final List<(String, String, String)> creates = [];
  final List<(String, String, String, String)> updates = [];
  int _nextId = 0;

  @override
  Future<List<Note>> fetchForUser(String userId) async =>
      List.of(byUser[userId] ?? const []);

  @override
  Future<Note> create(String userId, String title, String body) async {
    creates.add((userId, title, body));
    final note = _note('note-${++_nextId}', userId, title, body);
    byUser.putIfAbsent(userId, () => []).add(note);
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
    final note = _note(id, userId, title, body);
    final notes = byUser.putIfAbsent(userId, () => []);
    final index = notes.indexWhere((item) => item.id == id);
    if (index >= 0) notes[index] = note;
    return note;
  }

  @override
  Future<void> delete(String userId, String id) async {
    byUser[userId]?.removeWhere((note) => note.id == id);
  }
}

class _Attachments implements NoteAttachmentRepository {
  final List<NoteAttachment> uploaded = [];
  final List<String> events = [];
  final List<(String, String, int?)> uploadCalls = [];
  final Map<int, Object> uploadErrors = {};
  Object? deleteError;
  Object? fetchError;
  Completer<NoteAttachment>? pendingUpload;
  int _nextId = 0;

  @override
  Future<List<NoteAttachment>> fetchForNote({
    required String userId,
    required String noteId,
  }) async {
    if (fetchError case final error?) throw error;
    return uploaded
        .where((item) => item.userId == userId && item.noteId == noteId)
        .map((item) => item.withUrl('https://signed.test/${item.id}'))
        .toList();
  }

  @override
  Future<List<NoteAttachment>> fetchMetadataForNote({
    required String userId,
    required String noteId,
  }) async =>
      uploaded
          .where((item) => item.userId == userId && item.noteId == noteId)
          .toList();

  @override
  Future<NoteAttachment> uploadPreparedMedia({
    required String userId,
    required String noteId,
    required Uint8List bytes,
    required NoteAttachmentMediaType mediaType,
    required String mimeType,
    required String extension,
    int? durationSeconds,
  }) async {
    final marker = bytes.first;
    events.add('start-$marker');
    uploadCalls.add((userId, noteId, durationSeconds));
    if (pendingUpload case final pending?) {
      final attachment = await pending.future;
      uploaded.add(attachment);
      events.add('done-$marker');
      return attachment;
    }
    if (uploadErrors[marker] case final error?) throw error;
    final attachment = NoteAttachment(
      id: 'attachment-${++_nextId}',
      noteId: noteId,
      userId: userId,
      storagePath: '$userId/$noteId/attachment-$_nextId.$extension',
      mediaType: mediaType,
      mimeType: mimeType,
      fileSize: bytes.length,
      durationSeconds: durationSeconds,
      createdAt: null,
    );
    uploaded.add(attachment);
    events.add('done-$marker');
    return attachment;
  }

  @override
  Future<void> deleteAttachment({
    required String userId,
    required NoteAttachment attachment,
  }) async {
    events.add('delete-${attachment.id}');
    if (deleteError case final error?) throw error;
    uploaded.removeWhere((item) => item.id == attachment.id);
  }
}

Note _note(String id, String userId, String title, String body) => Note(
      id: id,
      userId: userId,
      title: title,
      body: body,
      createdAt: DayweaveTimestamp(DateTime.utc(2026, 10, 1)),
      updatedAt: DayweaveTimestamp(DateTime.utc(2026, 10, 2)),
    );

PickedNoteMedia _picked(String name, int marker, String mime) =>
    PickedNoteMedia(
      fileName: name,
      mimeType: mime,
      readBytes: () async => Uint8List.fromList([marker, 2, 3]),
    );

ProviderContainer _container({
  required _Notes notes,
  required _Attachments attachments,
  required _Picker picker,
  required _Preparation preparation,
}) =>
    ProviderContainer(overrides: [
      noteRepositoryProvider.overrideWithValue(notes),
      noteAttachmentRepositoryProvider.overrideWithValue(attachments),
      noteMediaPickerProvider.overrideWithValue(picker),
      noteMediaPreparationProvider.overrideWithValue(preparation),
      currentUserIdProvider.overrideWith((ref) => ref.watch(_userProvider)),
    ]);

void main() {
  test('picker cancellation returns no media and does not upload', () async {
    final attachments = _Attachments();
    final container = _container(
      notes: _Notes(),
      attachments: attachments,
      picker: _Picker([]),
      preparation: _Preparation(),
    );
    addTearDown(container.dispose);
    await container.read(notesProvider.notifier).load();

    final selection =
        await container.read(notesProvider.notifier).pickAndPrepareMedia();

    expect(selection.prepared, isEmpty);
    expect(selection.errors, isEmpty);
    expect(attachments.uploadCalls, isEmpty);
  });

  test(
      'multiple files prepare in selection order and unsupported files report errors',
      () async {
    final preparation = _Preparation()..unsupportedNames.add('bad.gif');
    final picker = _Picker([
      _picked('first.png', 1, 'image/png'),
      _picked('bad.gif', 2, 'application/octet-stream'),
      _picked('third.mp4', 3, 'video/mp4'),
    ]);
    final container = _container(
      notes: _Notes(),
      attachments: _Attachments(),
      picker: picker,
      preparation: preparation,
    );
    addTearDown(container.dispose);
    await container.read(notesProvider.notifier).load();

    final selection =
        await container.read(notesProvider.notifier).pickAndPrepareMedia();

    expect(preparation.preparedNames, ['first.png', 'bad.gif', 'third.mp4']);
    expect(selection.prepared.map((item) => item.fileName), [
      'first.png',
      'third.mp4',
    ]);
    expect(selection.errors, hasLength(1));
    expect(selection.errors.single, contains('bad.gif'));
  });

  test('upload forwards positive fractional duration rounded up to metadata',
      () async {
    final notes = _Notes();
    final attachments = _Attachments();
    final container = _container(
      notes: notes,
      attachments: attachments,
      picker: _Picker([]),
      preparation: _Preparation(),
    );
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);
    await controller.load();
    final note = await controller.createNote(title: 'Video', body: '');
    final prepared = await _Preparation().prepare(
      fileName: 'clip.mp4',
      mimeType: 'video/mp4',
      bytes: Uint8List.fromList([9, 8]),
    );

    await controller.uploadPreparedMedia(noteId: note.id, media: prepared);

    expect(attachments.uploadCalls, [('user-1', note.id, 10)]);
    expect(attachments.uploaded.single.durationSeconds, 10);
  });

  test('attachment loading exposes errors and can retry to signed URLs',
      () async {
    final notes = _Notes()
      ..byUser['user-1'] = [_note('n1', 'user-1', 'Note', '')];
    final attachments = _Attachments()
      ..fetchError = StateError('signing failed');
    final container = _container(
      notes: notes,
      attachments: attachments,
      picker: _Picker([]),
      preparation: _Preparation(),
    );
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);
    await controller.load();

    await controller.loadAttachments('n1');
    expect(container.read(notesProvider).attachmentLoadErrorsByNoteId['n1'],
        isA<StateError>());

    attachments.fetchError = null;
    attachments.uploaded.add(const NoteAttachment(
      id: 'a1',
      noteId: 'n1',
      userId: 'user-1',
      storagePath: 'user-1/n1/a1.jpg',
      mediaType: NoteAttachmentMediaType.image,
      mimeType: 'image/jpeg',
      fileSize: 3,
      durationSeconds: null,
      createdAt: null,
    ));
    await controller.loadAttachments('n1');

    expect(container.read(notesProvider).attachmentLoadErrorsByNoteId, isEmpty);
    expect(container.read(notesProvider).attachmentsByNoteId['n1']!.single.url,
        'https://signed.test/a1');
  });

  test('account change during upload prevents stale attachment state updates',
      () async {
    final notes = _Notes()
      ..byUser['user-1'] = [_note('n1', 'user-1', 'Note', '')];
    final attachments = _Attachments()
      ..pendingUpload = Completer<NoteAttachment>();
    final picker = _Picker([]);
    final preparation = _Preparation();
    final container = _container(
      notes: notes,
      attachments: attachments,
      picker: picker,
      preparation: preparation,
    );
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);
    await controller.load();
    final media = await preparation.prepare(
      fileName: 'image.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList([1]),
    );

    final uploading =
        controller.uploadPreparedMedia(noteId: 'n1', media: media);
    container.read(_userProvider.notifier).state = 'user-2';
    expect(container.read(currentUserIdProvider), 'user-2');
    attachments.pendingUpload!.complete(const NoteAttachment(
      id: 'old-account',
      noteId: 'n1',
      userId: 'user-1',
      storagePath: 'user-1/n1/old-account.jpg',
      mediaType: NoteAttachmentMediaType.image,
      mimeType: 'image/jpeg',
      fileSize: 1,
      durationSeconds: null,
      createdAt: null,
    ));

    await expectLater(uploading, throwsStateError);
    expect(container.read(notesProvider).userId, 'user-2');
    expect(container.read(notesProvider).attachmentsByNoteId, isEmpty);
    expect(attachments.uploadCalls.single.$1, 'user-1');
  });

  testWidgets(
      'sequential uploads resume after failure without duplicating success',
      (tester) async {
    final notes = _Notes();
    final attachments = _Attachments()..uploadErrors[2] = StateError('offline');
    final picker = _Picker([
      _picked('one.jpg', 1, 'image/jpeg'),
      _picked('two.png', 2, 'image/png'),
    ]);
    final preparation = _Preparation();
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        noteRepositoryProvider.overrideWithValue(notes),
        noteAttachmentRepositoryProvider.overrideWithValue(attachments),
        noteMediaPickerProvider.overrideWithValue(picker),
        noteMediaPreparationProvider.overrideWithValue(preparation),
        currentUserIdProvider.overrideWith((ref) => 'user-1'),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: messengerKey,
        home: const Scaffold(body: LooseNotesScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('note-title-field')), 'Media note');
    await tester.ensureVisible(find.byKey(const Key('add-note-media')));
    await tester.tap(find.byKey(const Key('add-note-media')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pending-media-0')), findsOneWidget);
    expect(find.byKey(const Key('pending-media-1')), findsOneWidget);

    await tester.ensureVisible(find.text('Save note'));
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();
    expect(attachments.events, ['start-1', 'done-1', 'start-2']);
    expect(find.textContaining('completed uploads will not be sent again'),
        findsOneWidget);
    expect(find.byKey(const Key('pending-media-0')), findsOneWidget);
    expect(attachments.uploaded, hasLength(1));
    expect(notes.creates, hasLength(1));

    attachments.uploadErrors.clear();
    messengerKey.currentState!.hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Retry upload'));
    await tester.tap(find.text('Retry upload'));
    await tester.pumpAndSettle();

    expect(attachments.events, [
      'start-1',
      'done-1',
      'start-2',
      'start-2',
      'done-2',
    ]);
    expect(attachments.uploaded.map((item) => item.storagePath), hasLength(2));
    expect(notes.creates, hasLength(1));
    expect(notes.updates, hasLength(1));
    expect(find.text('Media note'), findsOneWidget);
    expect(find.text('Image'), findsWidgets);
  });

  testWidgets('editor shows progress while a prepared upload is pending',
      (tester) async {
    final notes = _Notes();
    final attachments = _Attachments()
      ..pendingUpload = Completer<NoteAttachment>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        noteRepositoryProvider.overrideWithValue(notes),
        noteAttachmentRepositoryProvider.overrideWithValue(attachments),
        noteMediaPickerProvider.overrideWithValue(
          _Picker([_picked('progress.jpg', 4, 'image/jpeg')]),
        ),
        noteMediaPreparationProvider.overrideWithValue(_Preparation()),
        currentUserIdProvider.overrideWith((ref) => 'user-1'),
      ],
      child: const MaterialApp(home: Scaffold(body: LooseNotesScreen())),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note-title-field')),
      'Uploading note',
    );
    await tester.ensureVisible(find.byKey(const Key('add-note-media')));
    await tester.tap(find.byKey(const Key('add-note-media')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save note'));
    await tester.tap(find.text('Save note'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('note-upload-progress')), findsOneWidget);
    expect(find.textContaining('Uploading 1 of 1'), findsOneWidget);
    expect(find.text('Uploading…'), findsOneWidget);

    attachments.pendingUpload!.complete(const NoteAttachment(
      id: 'progress-attachment',
      noteId: 'note-1',
      userId: 'user-1',
      storagePath: 'user-1/note-1/progress-attachment.jpg',
      mediaType: NoteAttachmentMediaType.image,
      mimeType: 'image/jpeg',
      fileSize: 3,
      durationSeconds: null,
      createdAt: null,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Image'), findsWidgets);
    expect(attachments.uploadCalls, hasLength(1));
  });

  testWidgets('unconfirmed storage cleanup blocks retry of that file', (
    tester,
  ) async {
    final notes = _Notes();
    final attachments = _Attachments()
      ..uploadErrors[7] = const NoteAttachmentUploadCleanupException(
        metadataError: 'metadata failed',
        cleanupError: 'removal not confirmed',
      );
    final picker = _Picker([_picked('uncertain.jpg', 7, 'image/jpeg')]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        noteRepositoryProvider.overrideWithValue(notes),
        noteAttachmentRepositoryProvider.overrideWithValue(attachments),
        noteMediaPickerProvider.overrideWithValue(picker),
        noteMediaPreparationProvider.overrideWithValue(_Preparation()),
        currentUserIdProvider.overrideWith((ref) => 'user-1'),
      ],
      child: const MaterialApp(home: Scaffold(body: LooseNotesScreen())),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('note-title-field')), 'Orphan risk');
    await tester.ensureVisible(find.byKey(const Key('add-note-media')));
    await tester.tap(find.byKey(const Key('add-note-media')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save note'));
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('blocked from retry to avoid a duplicate'),
      findsOneWidget,
    );
    expect(find.text('Cleanup unconfirmed; retry is blocked'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Retry upload'),
          )
          .onPressed,
      isNull,
    );
    expect(notes.creates, hasLength(1));
    expect(attachments.uploadCalls, hasLength(1));
  });

  test('attachment delete failure retains the item for recovery', () async {
    final notes = _Notes()
      ..byUser['user-1'] = [_note('n1', 'user-1', 'Note', '')];
    final attachments = _Attachments()
      ..uploaded.add(const NoteAttachment(
        id: 'a1',
        noteId: 'n1',
        userId: 'user-1',
        storagePath: 'user-1/n1/a1.jpg',
        mediaType: NoteAttachmentMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 3,
        durationSeconds: null,
        createdAt: null,
      ))
      ..deleteError = StateError('Storage unavailable');
    final container = _container(
      notes: notes,
      attachments: attachments,
      picker: _Picker([]),
      preparation: _Preparation(),
    );
    addTearDown(container.dispose);
    final controller = container.read(notesProvider.notifier);
    await controller.load();
    await controller.loadAttachments('n1');
    final attachment =
        container.read(notesProvider).attachmentsByNoteId['n1']!.single;

    await expectLater(
      controller.deleteAttachment(noteId: 'n1', attachment: attachment),
      throwsStateError,
    );

    expect(attachments.events, ['delete-a1']);
    expect(
        container.read(notesProvider).attachmentsByNoteId['n1'], [attachment]);
    expect(container.read(notesProvider).isMutating, isFalse);

    attachments.deleteError = null;
    await controller.deleteAttachment(noteId: 'n1', attachment: attachment);
    expect(container.read(notesProvider).attachmentsByNoteId['n1'], isEmpty);
    expect(attachments.events, ['delete-a1', 'delete-a1']);
  });

  testWidgets('attachment removal requires confirmation and updates gallery',
      (tester) async {
    final notes = _Notes()
      ..byUser['user-1'] = [_note('n1', 'user-1', 'Media note', '')];
    final attachments = _Attachments()
      ..uploaded.add(const NoteAttachment(
        id: 'a1',
        noteId: 'n1',
        userId: 'user-1',
        storagePath: 'user-1/n1/a1.jpg',
        mediaType: NoteAttachmentMediaType.image,
        mimeType: 'image/jpeg',
        fileSize: 3,
        durationSeconds: null,
        createdAt: null,
      ));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        noteRepositoryProvider.overrideWithValue(notes),
        noteAttachmentRepositoryProvider.overrideWithValue(attachments),
        noteMediaPickerProvider.overrideWithValue(_Picker([])),
        noteMediaPreparationProvider.overrideWithValue(_Preparation()),
        currentUserIdProvider.overrideWith((ref) => 'user-1'),
      ],
      child: const MaterialApp(home: Scaffold(body: LooseNotesScreen())),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('note-row-n1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('remove-attachment')));
    await tester.tap(find.byKey(const Key('remove-attachment')));
    await tester.pumpAndSettle();
    expect(find.text('Remove this attachment?'), findsOneWidget);
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(attachments.events, isEmpty);
    expect(find.byKey(const Key('attachment-page-count')), findsOneWidget);

    attachments.deleteError = StateError('temporary storage error');
    await tester.ensureVisible(find.byKey(const Key('remove-attachment')));
    await tester.tap(find.byKey(const Key('remove-attachment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-attachment-delete')));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('attachment could not be removed'), findsOneWidget);
    expect(find.byKey(const Key('attachment-page-count')), findsOneWidget);

    attachments.deleteError = null;
    await tester.ensureVisible(find.byKey(const Key('remove-attachment')));
    await tester.tap(find.byKey(const Key('remove-attachment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-attachment-delete')));
    await tester.pumpAndSettle();

    expect(attachments.events, ['delete-a1', 'delete-a1']);
    expect(find.byKey(const Key('attachment-page-count')), findsNothing);
    expect(find.text('Attachment removed'), findsOneWidget);
  });
}
