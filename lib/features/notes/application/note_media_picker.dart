import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'note_media_preparation.dart';

class PickedNoteMedia {
  const PickedNoteMedia({
    required this.fileName,
    required this.mimeType,
    required this.readBytes,
  });

  final String fileName;
  final String mimeType;
  final Future<Uint8List> Function() readBytes;
}

abstract interface class NoteMediaPicker {
  /// An empty list represents a user cancellation.
  Future<List<PickedNoteMedia>> pickMultiple();
}

class FilePickerNoteMediaPicker implements NoteMediaPicker {
  const FilePickerNoteMediaPicker();

  @override
  Future<List<PickedNoteMedia>> pickMultiple() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'webm'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return const [];

    final picked = <PickedNoteMedia>[];
    for (final file in result.files) {
      final extension = (file.extension ?? _extension(file.name)).toLowerCase();
      picked.add(PickedNoteMedia(
        fileName: file.name,
        mimeType: _mimeType(extension),
        readBytes: () async {
          if (file.bytes case final bytes?) return bytes;
          if (file.path case final path?) return File(path).readAsBytes();
          throw FormatException('Could not read ${file.name}.');
        },
      ));
    }
    return picked;
  }
}

final noteMediaPickerProvider = Provider<NoteMediaPicker>(
  (ref) => const FilePickerNoteMediaPicker(),
);

final noteMediaPreparationProvider = Provider<NoteMediaPreparationService>(
  (ref) => DefaultNoteMediaPreparationService(),
);

String _extension(String name) {
  final separator = name.lastIndexOf('.');
  return separator < 0 ? '' : name.substring(separator + 1);
}

String _mimeType(String extension) => switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'webm' => 'video/webm',
      _ => 'application/octet-stream',
    };
