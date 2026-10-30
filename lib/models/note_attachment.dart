import '../core/date_time/dayweave_date_time.dart';

enum NoteAttachmentMediaType {
  image,
  video;

  factory NoteAttachmentMediaType.fromDatabase(Object? value) =>
      switch (value) {
        'image' => NoteAttachmentMediaType.image,
        'video' => NoteAttachmentMediaType.video,
        _ =>
          throw FormatException('Unknown note attachment media type: $value'),
      };
}

/// Database metadata plus an optional, short-lived URL for runtime display.
/// The URL is intentionally not read from or written to the database.
class NoteAttachment {
  const NoteAttachment({
    required this.id,
    required this.noteId,
    required this.userId,
    required this.storagePath,
    required this.mediaType,
    required this.mimeType,
    required this.fileSize,
    required this.durationSeconds,
    required this.createdAt,
    this.url,
  });

  factory NoteAttachment.fromDatabase(
    Map<String, dynamic> row, {
    String? url,
  }) =>
      NoteAttachment(
        id: _requiredString(row, 'id'),
        noteId: _requiredString(row, 'note_id'),
        userId: _requiredString(row, 'user_id'),
        storagePath: _requiredString(row, 'storage_path'),
        mediaType: NoteAttachmentMediaType.fromDatabase(row['media_type']),
        mimeType: _requiredString(row, 'mime_type'),
        fileSize: _requiredInt(row, 'file_size'),
        durationSeconds: _nullableInt(row['duration_seconds']),
        createdAt: _nullableTimestamp(row['created_at']),
        url: url,
      );

  final String id;
  final String noteId;
  final String userId;
  final String storagePath;
  final NoteAttachmentMediaType mediaType;
  final String mimeType;
  final int fileSize;
  final int? durationSeconds;
  final DayweaveTimestamp? createdAt;

  /// A runtime-only signed URL. Never include this field in a database payload.
  final String? url;

  NoteAttachment withUrl(String value) => NoteAttachment(
        id: id,
        noteId: noteId,
        userId: userId,
        storagePath: storagePath,
        mediaType: mediaType,
        mimeType: mimeType,
        fileSize: fileSize,
        durationSeconds: durationSeconds,
        createdAt: createdAt,
        url: value,
      );
}

String _requiredString(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value == null) {
    throw FormatException('Missing note attachment field: $key');
  }
  return value.toString();
}

int _requiredInt(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is num) return value.toInt();
  if (value is String) return int.parse(value);
  throw FormatException('Invalid note attachment field: $key');
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) return int.parse(value);
  throw const FormatException('Invalid duration_seconds value.');
}

DayweaveTimestamp? _nullableTimestamp(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return DayweaveTimestamp(value.toUtc());
  if (value is String) return DayweaveTimestamp.parse(value);
  throw const FormatException('Invalid note attachment created_at value.');
}
