import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/note_attachment.dart';

const noteMediaBucket = 'note-media';
const noteAttachmentSignedUrlLifetimeSeconds = 3600;

abstract interface class NoteAttachmentRepository {
  Future<NoteAttachment> uploadPreparedMedia({
    required String userId,
    required String noteId,
    required Uint8List bytes,
    required NoteAttachmentMediaType mediaType,
    required String mimeType,
    required String extension,
    int? durationSeconds,
  });

  Future<List<NoteAttachment>> fetchForNote({
    required String userId,
    required String noteId,
  });

  /// Fetches metadata without requesting signed URLs, for cleanup/reconciliation.
  Future<List<NoteAttachment>> fetchMetadataForNote({
    required String userId,
    required String noteId,
  });

  Future<void> deleteAttachment({
    required String userId,
    required NoteAttachment attachment,
  });
}

/// Narrow remote-operation seam, allowing repository orchestration to be
/// tested without a live Supabase client or HTTP connection.
abstract interface class NoteAttachmentDataSource {
  Future<void> uploadObject({
    required String path,
    required Uint8List bytes,
    required String mimeType,
  });

  Future<Map<String, dynamic>> insertMetadata(Map<String, dynamic> values);

  Future<List<Map<String, dynamic>>> fetchMetadata({
    required String userId,
    required String noteId,
  });

  Future<String> createSignedUrl(String path, int expiresInSeconds);

  /// Returns true only when the Storage API confirms this path was removed.
  Future<bool> removeObject(String path);

  Future<void> deleteMetadata({
    required String attachmentId,
    required String userId,
  });
}

class SupabaseNoteAttachmentDataSource implements NoteAttachmentDataSource {
  SupabaseNoteAttachmentDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<void> uploadObject({
    required String path,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    await _client.storage.from(noteMediaBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
  }

  @override
  Future<Map<String, dynamic>> insertMetadata(
      Map<String, dynamic> values) async {
    final row =
        await _client.from('note_attachments').insert(values).select().single();
    return row;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMetadata({
    required String userId,
    required String noteId,
  }) async {
    final rows = await _client
        .from('note_attachments')
        .select()
        .eq('note_id', noteId)
        .eq('user_id', userId)
        .order('created_at', ascending: true);
    return rows;
  }

  @override
  Future<String> createSignedUrl(String path, int expiresInSeconds) =>
      _client.storage
          .from(noteMediaBucket)
          .createSignedUrl(path, expiresInSeconds);

  @override
  Future<bool> removeObject(String path) async {
    final removed = await _client.storage.from(noteMediaBucket).remove([path]);
    return removed.any((object) => object.name == path);
  }

  @override
  Future<void> deleteMetadata({
    required String attachmentId,
    required String userId,
  }) async {
    await _client
        .from('note_attachments')
        .delete()
        .eq('id', attachmentId)
        .eq('user_id', userId);
  }
}

class NoteAttachmentUploadCleanupException implements Exception {
  const NoteAttachmentUploadCleanupException({
    required this.metadataError,
    required this.cleanupError,
  });

  final Object metadataError;
  final Object cleanupError;

  @override
  String toString() =>
      'Attachment metadata insertion failed ($metadataError), and uploaded '
      'object cleanup also failed ($cleanupError).';
}

class NoteAttachmentObjectRemovalUnconfirmedException implements Exception {
  const NoteAttachmentObjectRemovalUnconfirmedException(this.storagePath);

  final String storagePath;

  @override
  String toString() =>
      'Storage did not confirm removal of note attachment $storagePath.';
}

/// Storage removal succeeded, but deleting the metadata row failed. A retry
/// through this repository instance can safely resume at the metadata step.
class NoteAttachmentMetadataDeletionException implements Exception {
  const NoteAttachmentMetadataDeletionException(this.cause);

  final Object cause;

  @override
  String toString() =>
      'Storage removal succeeded, but attachment metadata deletion failed: $cause';
}

class SupabaseNoteAttachmentRepository implements NoteAttachmentRepository {
  SupabaseNoteAttachmentRepository(
    SupabaseClient client, {
    String Function()? idGenerator,
  }) : this.withDataSource(
          SupabaseNoteAttachmentDataSource(client),
          idGenerator: idGenerator,
        );

  @visibleForTesting
  SupabaseNoteAttachmentRepository.withDataSource(
    NoteAttachmentDataSource dataSource, {
    String Function()? idGenerator,
  })  : _dataSource = dataSource,
        _idGenerator = idGenerator ?? _generateUuidV4;

  final NoteAttachmentDataSource _dataSource;
  final String Function() _idGenerator;
  final Set<String> _storageRemovedAwaitingMetadata = {};

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
    if (userId.isEmpty || noteId.isEmpty) {
      throw ArgumentError('A user and note are required to attach media.');
    }
    _validatePathSegment(userId, 'userId');
    _validatePathSegment(noteId, 'noteId');
    if (bytes.isEmpty) throw ArgumentError('Media bytes cannot be empty.');
    _validateMimeAndExtension(mediaType, mimeType, extension);
    if (durationSeconds != null && durationSeconds < 0) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }

    final attachmentId = _idGenerator();
    final normalizedExtension =
        extension.replaceFirst(RegExp(r'^\.'), '').toLowerCase();
    final storagePath = '$userId/$noteId/$attachmentId.$normalizedExtension';
    await _dataSource.uploadObject(
      path: storagePath,
      bytes: bytes,
      mimeType: mimeType,
    );

    final metadata = <String, dynamic>{
      'id': attachmentId,
      'note_id': noteId,
      'user_id': userId,
      'storage_path': storagePath,
      'media_type': mediaType.name,
      'mime_type': mimeType,
      'file_size': bytes.length,
      'duration_seconds': durationSeconds,
    };

    late final Map<String, dynamic> row;
    try {
      row = await _dataSource.insertMetadata(metadata);
    } catch (metadataError, stackTrace) {
      try {
        final removed = await _dataSource.removeObject(storagePath);
        if (!removed) {
          throw NoteAttachmentObjectRemovalUnconfirmedException(storagePath);
        }
      } catch (cleanupError) {
        throw NoteAttachmentUploadCleanupException(
          metadataError: metadataError,
          cleanupError: cleanupError,
        );
      }
      Error.throwWithStackTrace(metadataError, stackTrace);
    }
    return NoteAttachment.fromDatabase(row);
  }

  @override
  Future<List<NoteAttachment>> fetchForNote({
    required String userId,
    required String noteId,
  }) async {
    final attachments = await fetchMetadataForNote(
      userId: userId,
      noteId: noteId,
    );
    return Future.wait(attachments.map((attachment) async {
      final url = await _dataSource.createSignedUrl(
        attachment.storagePath,
        noteAttachmentSignedUrlLifetimeSeconds,
      );
      return attachment.withUrl(url);
    }));
  }

  @override
  Future<List<NoteAttachment>> fetchMetadataForNote({
    required String userId,
    required String noteId,
  }) async {
    final rows = await _dataSource.fetchMetadata(
      userId: userId,
      noteId: noteId,
    );
    return rows.map(NoteAttachment.fromDatabase).toList(growable: false);
  }

  @override
  Future<void> deleteAttachment({
    required String userId,
    required NoteAttachment attachment,
  }) async {
    if (userId != attachment.userId ||
        !attachment.storagePath.startsWith('$userId/${attachment.noteId}/')) {
      throw StateError('The attachment does not belong to the current user.');
    }
    final key =
        '$userId:${attachment.noteId}:${attachment.id}:${attachment.storagePath}';
    if (!_storageRemovedAwaitingMetadata.contains(key)) {
      final removed = await _dataSource.removeObject(attachment.storagePath);
      if (!removed) {
        throw NoteAttachmentObjectRemovalUnconfirmedException(
          attachment.storagePath,
        );
      }
      _storageRemovedAwaitingMetadata.add(key);
    }
    try {
      await _dataSource.deleteMetadata(
        attachmentId: attachment.id,
        userId: userId,
      );
      _storageRemovedAwaitingMetadata.remove(key);
    } catch (error) {
      throw NoteAttachmentMetadataDeletionException(error);
    }
  }
}

void _validatePathSegment(String value, String name) {
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
    throw ArgumentError.value(
        value, name, 'Must be a single safe path segment.');
  }
}

void _validateMimeAndExtension(
  NoteAttachmentMediaType mediaType,
  String mimeType,
  String extension,
) {
  final normalizedExtension =
      extension.replaceFirst(RegExp(r'^\.'), '').toLowerCase();
  const mimeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'mp4': 'video/mp4',
    'webm': 'video/webm',
  };
  final expectedMime = mimeByExtension[normalizedExtension];
  final expectedMediaType = mimeType.startsWith('image/')
      ? NoteAttachmentMediaType.image
      : mimeType.startsWith('video/')
          ? NoteAttachmentMediaType.video
          : null;
  if (expectedMime != mimeType || expectedMediaType != mediaType) {
    throw ArgumentError('Media type, MIME type, and extension must agree.');
  }
}

String _generateUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
