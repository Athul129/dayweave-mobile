import 'dart:typed_data';

import 'package:dayweave_mobile/models/note_attachment.dart';
import 'package:dayweave_mobile/repositories/note_attachment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDataSource implements NoteAttachmentDataSource {
  final List<String> events = [];
  final List<Map<String, dynamic>> insertedRows = [];
  List<Map<String, dynamic>> fetchRows = [];
  String? fetchedUserId;
  String? fetchedNoteId;
  final List<(String, int)> signedRequests = [];
  Object? insertError;
  Object? removeError;
  bool removalConfirmed = true;
  Object? deleteMetadataError;
  String signedUrl = 'https://example.test/signed';
  String? uploadedPath;
  Uint8List? uploadedBytes;
  String? uploadedMimeType;
  String? removedPath;
  String? deletedAttachmentId;
  String? deletedUserId;

  @override
  Future<void> uploadObject({
    required String path,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    events.add('upload');
    uploadedPath = path;
    uploadedBytes = bytes;
    uploadedMimeType = mimeType;
  }

  @override
  Future<Map<String, dynamic>> insertMetadata(
    Map<String, dynamic> values,
  ) async {
    events.add('insert-metadata');
    insertedRows.add(Map.of(values));
    if (insertError case final error?) throw error;
    return {
      ...values,
      'created_at': '2026-10-29T10:30:00Z',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMetadata({
    required String userId,
    required String noteId,
  }) async {
    events.add('fetch-metadata');
    fetchedUserId = userId;
    fetchedNoteId = noteId;
    return fetchRows;
  }

  @override
  Future<String> createSignedUrl(String path, int expiresInSeconds) async {
    events.add('signed-url');
    signedRequests.add((path, expiresInSeconds));
    return signedUrl;
  }

  @override
  Future<bool> removeObject(String path) async {
    events.add('remove-object');
    removedPath = path;
    if (removeError case final error?) throw error;
    return removalConfirmed;
  }

  @override
  Future<void> deleteMetadata({
    required String attachmentId,
    required String userId,
  }) async {
    events.add('delete-metadata');
    deletedAttachmentId = attachmentId;
    deletedUserId = userId;
    if (deleteMetadataError case final error?) throw error;
  }
}

Map<String, dynamic> _row({
  String id = 'attachment-1',
  String noteId = 'note-1',
  String userId = 'user-1',
  String path = 'user-1/note-1/attachment-1.jpg',
  String mediaType = 'image',
  String mimeType = 'image/jpeg',
  int fileSize = 42,
  Object? durationSeconds,
  Object? createdAt = '2026-10-29T10:30:00Z',
}) =>
    {
      'id': id,
      'note_id': noteId,
      'user_id': userId,
      'storage_path': path,
      'media_type': mediaType,
      'mime_type': mimeType,
      'file_size': fileSize,
      'duration_seconds': durationSeconds,
      'created_at': createdAt,
    };

NoteAttachment _attachment() => NoteAttachment.fromDatabase(_row());

SupabaseNoteAttachmentRepository _repository(
  _FakeDataSource source, {
  String Function()? idGenerator,
}) =>
    SupabaseNoteAttachmentRepository.withDataSource(
      source,
      idGenerator: idGenerator,
    );

void main() {
  group('NoteAttachment model', () {
    test('maps metadata and keeps runtime URL separate', () {
      final attachment = NoteAttachment.fromDatabase(
        _row(durationSeconds: 7),
        url: 'https://example.test/runtime-only',
      );

      expect(attachment.id, 'attachment-1');
      expect(attachment.noteId, 'note-1');
      expect(attachment.userId, 'user-1');
      expect(attachment.storagePath, 'user-1/note-1/attachment-1.jpg');
      expect(attachment.mediaType, NoteAttachmentMediaType.image);
      expect(attachment.mimeType, 'image/jpeg');
      expect(attachment.fileSize, 42);
      expect(attachment.durationSeconds, 7);
      expect(attachment.createdAt?.value, DateTime.utc(2026, 10, 29, 10, 30));
      expect(attachment.url, 'https://example.test/runtime-only');
    });

    test('accepts nullable duration and timestamp values', () {
      final attachment = NoteAttachment.fromDatabase(
        _row(durationSeconds: null, createdAt: null),
      );

      expect(attachment.durationSeconds, isNull);
      expect(attachment.createdAt, isNull);
    });

    test('normalizes a DateTime timestamp to UTC', () {
      final attachment = NoteAttachment.fromDatabase(
        _row(createdAt: DateTime(2026, 10, 29, 15, 30)),
      );

      expect(attachment.createdAt?.value.isUtc, isTrue);
    });
  });

  group('SupabaseNoteAttachmentRepository', () {
    test('uploads bytes then inserts contract metadata without a URL',
        () async {
      final source = _FakeDataSource();
      final repository =
          _repository(source, idGenerator: () => 'attachment-id');
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      final attachment = await repository.uploadPreparedMedia(
        userId: 'user-1',
        noteId: 'note-1',
        bytes: bytes,
        mediaType: NoteAttachmentMediaType.image,
        mimeType: 'image/jpeg',
        extension: 'jpg',
      );

      expect(source.events, ['upload', 'insert-metadata']);
      expect(source.uploadedPath, 'user-1/note-1/attachment-id.jpg');
      expect(source.uploadedBytes, bytes);
      expect(source.uploadedMimeType, 'image/jpeg');
      expect(source.insertedRows.single, {
        'id': 'attachment-id',
        'note_id': 'note-1',
        'user_id': 'user-1',
        'storage_path': 'user-1/note-1/attachment-id.jpg',
        'media_type': 'image',
        'mime_type': 'image/jpeg',
        'file_size': 4,
        'duration_seconds': null,
      });
      expect(source.insertedRows.single.containsKey('url'), isFalse);
      expect(attachment.url, isNull);
      expect(attachment.createdAt?.value, DateTime.utc(2026, 10, 29, 10, 30));
    });

    test('generates a UUID v4 when no ID generator is injected', () async {
      final source = _FakeDataSource();
      await _repository(source).uploadPreparedMedia(
        userId: 'user-1',
        noteId: 'note-1',
        bytes: Uint8List.fromList([1]),
        mediaType: NoteAttachmentMediaType.video,
        mimeType: 'video/webm',
        extension: '.webm',
        durationSeconds: 4,
      );

      expect(
        source.uploadedPath,
        matches(RegExp(
          r'^user-1/note-1/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.webm$',
        )),
      );
    });

    test('fetch scopes by user and note and maps ordered signed URLs',
        () async {
      final source = _FakeDataSource()
        ..fetchRows = [
          _row(id: 'first', path: 'user-1/note-1/first.jpg'),
          _row(
            id: 'second',
            path: 'user-1/note-1/second.mp4',
            mediaType: 'video',
            mimeType: 'video/mp4',
            durationSeconds: 8,
          ),
        ];
      final attachments = await _repository(source).fetchForNote(
        userId: 'user-1',
        noteId: 'note-1',
      );

      expect(source.fetchedUserId, 'user-1');
      expect(source.fetchedNoteId, 'note-1');
      expect(attachments.map((item) => item.id), ['first', 'second']);
      expect(attachments.map((item) => item.url), [
        source.signedUrl,
        source.signedUrl,
      ]);
      expect(source.signedRequests, [
        ('user-1/note-1/first.jpg', 3600),
        ('user-1/note-1/second.mp4', 3600),
      ]);
      expect(source.events, [
        'fetch-metadata',
        'signed-url',
        'signed-url',
      ]);
    });

    test('metadata-only fetch does not require a signed URL', () async {
      final source = _FakeDataSource()
        ..fetchRows = [_row(path: 'user-1/note-1/retry.jpg')];

      final attachments = await _repository(source).fetchMetadataForNote(
        userId: 'user-1',
        noteId: 'note-1',
      );

      expect(attachments.single.storagePath, 'user-1/note-1/retry.jpg');
      expect(attachments.single.url, isNull);
      expect(source.fetchedUserId, 'user-1');
      expect(source.fetchedNoteId, 'note-1');
      expect(source.signedRequests, isEmpty);
    });

    test('cleans up uploaded object after metadata insertion failure',
        () async {
      final insertFailure = StateError('metadata insert failed');
      final source = _FakeDataSource()..insertError = insertFailure;
      final repository = _repository(source, idGenerator: () => 'failed-id');

      await expectLater(
        repository.uploadPreparedMedia(
          userId: 'user-1',
          noteId: 'note-1',
          bytes: Uint8List.fromList([1, 2]),
          mediaType: NoteAttachmentMediaType.image,
          mimeType: 'image/png',
          extension: 'png',
        ),
        throwsA(same(insertFailure)),
      );
      expect(source.events, ['upload', 'insert-metadata', 'remove-object']);
      expect(source.removedPath, 'user-1/note-1/failed-id.png');
    });

    test('reports both metadata and cleanup failures', () async {
      final insertFailure = StateError('metadata insert failed');
      final cleanupFailure = StateError('storage cleanup failed');
      final source = _FakeDataSource()
        ..insertError = insertFailure
        ..removeError = cleanupFailure;

      await expectLater(
        _repository(source, idGenerator: () => 'failed-id').uploadPreparedMedia(
          userId: 'user-1',
          noteId: 'note-1',
          bytes: Uint8List.fromList([1]),
          mediaType: NoteAttachmentMediaType.image,
          mimeType: 'image/jpeg',
          extension: 'jpg',
        ),
        throwsA(
          isA<NoteAttachmentUploadCleanupException>()
              .having((error) => error.metadataError, 'metadataError',
                  insertFailure)
              .having((error) => error.cleanupError, 'cleanupError',
                  cleanupFailure),
        ),
      );
    });

    test('deletes Storage object before user-scoped metadata', () async {
      final source = _FakeDataSource();
      await _repository(source).deleteAttachment(
        userId: 'user-1',
        attachment: _attachment(),
      );

      expect(source.events, ['remove-object', 'delete-metadata']);
      expect(source.removedPath, 'user-1/note-1/attachment-1.jpg');
      expect(source.deletedAttachmentId, 'attachment-1');
      expect(source.deletedUserId, 'user-1');
    });

    test('metadata delete failure is explicit after Storage removal', () async {
      final failure = StateError('metadata delete failed');
      final source = _FakeDataSource()..deleteMetadataError = failure;
      final repository = _repository(source);

      await expectLater(
        repository.deleteAttachment(
          userId: 'user-1',
          attachment: _attachment(),
        ),
        throwsA(isA<NoteAttachmentMetadataDeletionException>()),
      );
      expect(source.events, ['remove-object', 'delete-metadata']);

      source.deleteMetadataError = null;
      await repository.deleteAttachment(
        userId: 'user-1',
        attachment: _attachment(),
      );
      expect(source.events, [
        'remove-object',
        'delete-metadata',
        'delete-metadata',
      ]);
    });

    test('does not delete metadata if Storage removal fails', () async {
      final failure = StateError('storage removal failed');
      final source = _FakeDataSource()..removeError = failure;

      await expectLater(
        _repository(source).deleteAttachment(
          userId: 'user-1',
          attachment: _attachment(),
        ),
        throwsA(same(failure)),
      );
      expect(source.events, ['remove-object']);
    });

    test('does not delete metadata when Storage removal is unconfirmed',
        () async {
      final source = _FakeDataSource()..removalConfirmed = false;

      await expectLater(
        _repository(source).deleteAttachment(
          userId: 'user-1',
          attachment: _attachment(),
        ),
        throwsA(isA<NoteAttachmentObjectRemovalUnconfirmedException>()),
      );
      expect(source.events, ['remove-object']);
      expect(source.deletedAttachmentId, isNull);
    });

    test('rejects deleting an attachment owned by another user', () async {
      final source = _FakeDataSource();

      await expectLater(
        _repository(source).deleteAttachment(
          userId: 'user-2',
          attachment: _attachment(),
        ),
        throwsStateError,
      );
      expect(source.events, isEmpty);
    });

    test('rejects mismatched extension and MIME type before upload', () async {
      final source = _FakeDataSource();

      await expectLater(
        _repository(source).uploadPreparedMedia(
          userId: 'user-1',
          noteId: 'note-1',
          bytes: Uint8List.fromList([1]),
          mediaType: NoteAttachmentMediaType.image,
          mimeType: 'image/jpeg',
          extension: 'png',
        ),
        throwsArgumentError,
      );
      expect(source.events, isEmpty);
    });

    test('rejects path segments that could escape the storage prefix',
        () async {
      final source = _FakeDataSource();

      await expectLater(
        _repository(source).uploadPreparedMedia(
          userId: 'user-1',
          noteId: '../other-note',
          bytes: Uint8List.fromList([1]),
          mediaType: NoteAttachmentMediaType.image,
          mimeType: 'image/jpeg',
          extension: 'jpg',
        ),
        throwsArgumentError,
      );
      expect(source.events, isEmpty);
    });
  });
}
