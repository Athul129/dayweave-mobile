import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:video_player/video_player.dart';

import '../../../models/note_attachment.dart';

const noteImageMaxDimension = 1600;
const noteImageMaxBytes = 2 * 1024 * 1024;
const noteVideoMaxBytes = 5 * 1024 * 1024;
const noteVideoMaxDurationSeconds = 10.0;

class PreparedNoteMedia {
  const PreparedNoteMedia({
    required this.fileName,
    required this.bytes,
    required this.mediaType,
    required this.mimeType,
    required this.extension,
    required this.durationSeconds,
  });

  final String fileName;
  final Uint8List bytes;
  final NoteAttachmentMediaType mediaType;
  final String mimeType;
  final String extension;
  final double? durationSeconds;
}

class NoteMediaPreparationException implements Exception {
  const NoteMediaPreparationException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

abstract interface class NoteMediaPreparationService {
  Future<PreparedNoteMedia> prepare({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  });
}

abstract interface class NoteVideoDurationInspector {
  Future<double?> durationSeconds({
    required Uint8List bytes,
    required String extension,
  });
}

abstract interface class NoteImageJpegProcessor {
  Future<Uint8List> process(Uint8List bytes);
}

class DartNoteImageJpegProcessor implements NoteImageJpegProcessor {
  @override
  Future<Uint8List> process(Uint8List bytes) =>
      Isolate.run(() => _resizeAndEncodeJpeg(bytes));
}

class PlatformNoteVideoDurationInspector implements NoteVideoDurationInspector {
  const PlatformNoteVideoDurationInspector();

  @override
  Future<double?> durationSeconds({
    required Uint8List bytes,
    required String extension,
  }) async {
    final directory = await Directory.systemTemp.createTemp('dayweave-video-');
    final file = File('${directory.path}/source.$extension');
    final controller = VideoPlayerController.file(file);
    try {
      await file.writeAsBytes(bytes, flush: true);
      await controller.initialize();
      return controller.value.duration.inMilliseconds /
          Duration.millisecondsPerSecond;
    } finally {
      await controller.dispose();
      await directory.delete(recursive: true);
    }
  }
}

class DefaultNoteMediaPreparationService
    implements NoteMediaPreparationService {
  DefaultNoteMediaPreparationService({
    NoteVideoDurationInspector? videoDurationInspector,
    NoteImageJpegProcessor? imageProcessor,
  })  : _videoDurationInspector =
            videoDurationInspector ?? PlatformNoteVideoDurationInspector(),
        _imageProcessor = imageProcessor ?? DartNoteImageJpegProcessor();

  final NoteVideoDurationInspector _videoDurationInspector;
  final NoteImageJpegProcessor _imageProcessor;

  @override
  Future<PreparedNoteMedia> prepare({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      throw const NoteMediaPreparationException('This file is empty.');
    }

    final normalizedMimeType = mimeType.trim().toLowerCase();
    final extension = _extensionForMime(normalizedMimeType);
    if (normalizedMimeType.startsWith('image/')) {
      final jpegBytes = await _processImage(bytes);
      if (jpegBytes.length > noteImageMaxBytes) {
        throw const NoteMediaPreparationException(
          'Images must be 2 MB or smaller.',
        );
      }
      return PreparedNoteMedia(
        fileName: _jpegName(fileName),
        bytes: jpegBytes,
        mediaType: NoteAttachmentMediaType.image,
        mimeType: 'image/jpeg',
        extension: 'jpg',
        durationSeconds: null,
      );
    }

    if (normalizedMimeType.startsWith('video/')) {
      if (bytes.length > noteVideoMaxBytes) {
        throw const NoteMediaPreparationException(
          'Videos must be 5 MB or smaller.',
        );
      }
      final duration = await _inspectVideo(bytes, extension);
      if (duration == null || !duration.isFinite || duration <= 0) {
        throw const NoteMediaPreparationException(
          'This video could not be read.',
        );
      }
      if (duration > noteVideoMaxDurationSeconds) {
        throw const NoteMediaPreparationException(
          'Videos must be 10 seconds or shorter.',
        );
      }
      return PreparedNoteMedia(
        fileName: fileName,
        bytes: bytes,
        mediaType: NoteAttachmentMediaType.video,
        mimeType: normalizedMimeType,
        extension: extension,
        durationSeconds: duration,
      );
    }

    throw const NoteMediaPreparationException(
      'Use JPG, PNG, WebP, MP4, or WebM files.',
    );
  }

  Future<Uint8List> _processImage(Uint8List bytes) async {
    try {
      final result = await _imageProcessor.process(bytes);
      if (result.isEmpty) {
        throw const FormatException('The processed image is empty.');
      }
      return result;
    } on NoteMediaPreparationException {
      rethrow;
    } catch (error) {
      throw NoteMediaPreparationException(
        'This image could not be read.',
        cause: error,
      );
    }
  }

  Future<double?> _inspectVideo(Uint8List bytes, String extension) async {
    try {
      return await _videoDurationInspector.durationSeconds(
        bytes: bytes,
        extension: extension,
      );
    } catch (error) {
      throw NoteMediaPreparationException(
        'This video could not be read.',
        cause: error,
      );
    }
  }
}

String _extensionForMime(String mimeType) {
  const extensionByMime = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'video/mp4': 'mp4',
    'video/webm': 'webm',
  };
  final extension = extensionByMime[mimeType];
  if (extension == null) {
    throw const NoteMediaPreparationException(
      'Use JPG, PNG, WebP, MP4, or WebM files.',
    );
  }
  return extension;
}

String _jpegName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final baseName = dot > 0 ? fileName.substring(0, dot) : fileName;
  return '$baseName.jpg';
}

Uint8List _resizeAndEncodeJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    throw const FormatException('Unsupported or corrupt image data.');
  }
  final oriented = img.bakeOrientation(decoded);
  final longestSide =
      oriented.width > oriented.height ? oriented.width : oriented.height;
  final resized = longestSide <= noteImageMaxDimension
      ? oriented
      : img.copyResize(
          oriented,
          width: (oriented.width * noteImageMaxDimension / longestSide).round(),
          height:
              (oriented.height * noteImageMaxDimension / longestSide).round(),
        );
  return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
}
