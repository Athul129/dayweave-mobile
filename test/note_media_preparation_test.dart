import 'dart:typed_data';

import 'package:dayweave_mobile/features/notes/application/note_media_preparation.dart';
import 'package:dayweave_mobile/models/note_attachment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

class _FakeVideoDurationInspector implements NoteVideoDurationInspector {
  _FakeVideoDurationInspector(this.duration);

  double? duration;
  Object? error;
  Uint8List? receivedBytes;
  String? receivedExtension;

  @override
  Future<double?> durationSeconds({
    required Uint8List bytes,
    required String extension,
  }) async {
    receivedBytes = bytes;
    receivedExtension = extension;
    if (error case final value?) throw value;
    return duration;
  }
}

class _FakeImageProcessor implements NoteImageJpegProcessor {
  _FakeImageProcessor(this.output);

  final Uint8List output;

  @override
  Future<Uint8List> process(Uint8List bytes) async => output;
}

img.Image _image({int width = 8, int height = 4}) {
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    pixel
      ..r = pixel.x % 256
      ..g = pixel.y % 256
      ..b = 140;
  }
  return image;
}

Uint8List _pngImage({int width = 8, int height = 4}) =>
    Uint8List.fromList(img.encodePng(_image(width: width, height: height)));

DefaultNoteMediaPreparationService _service({
  NoteVideoDurationInspector? videoInspector,
  NoteImageJpegProcessor? imageProcessor,
}) =>
    DefaultNoteMediaPreparationService(
      videoDurationInspector: videoInspector ?? _FakeVideoDurationInspector(4),
      imageProcessor: imageProcessor,
    );

void main() {
  group('Note media preparation', () {
    test('accepts supported image MIME and extension combinations', () async {
      final cases = [
        ('photo.jpg', 'image/jpeg', img.encodeJpg(_image())),
        ('photo.jpeg', 'image/jpeg', img.encodeJpg(_image())),
        ('photo.png', 'image/png', img.encodePng(_image())),
        ('photo.webp', 'image/webp', img.encodeWebP(_image())),
      ];

      for (final (name, mimeType, input) in cases) {
        final result = await _service().prepare(
          fileName: name,
          mimeType: mimeType,
          bytes: Uint8List.fromList(input),
        );
        expect(result.mediaType, NoteAttachmentMediaType.image);
        expect(result.mimeType, 'image/jpeg');
        expect(result.extension, 'jpg');
        expect(result.fileName, 'photo.jpg');
        expect(result.durationSeconds, isNull);
      }
    });

    test('decodes WebP input and returns JPEG output', () async {
      final source = img.Image(width: 10, height: 6);
      final webp = Uint8List.fromList(img.encodeWebP(source));
      final result = await _service().prepare(
        fileName: 'capture.webp',
        mimeType: 'image/webp',
        bytes: webp,
      );

      expect(result.bytes.take(2), [0xff, 0xd8]);
      expect(img.decodeJpg(result.bytes), isNotNull);
      expect(result.fileName, 'capture.jpg');
    });

    test('resizes longest image dimension to 1600 and preserves aspect',
        () async {
      final result = await _service().prepare(
        fileName: 'wide.png',
        mimeType: 'image/png',
        bytes: _pngImage(width: 2000, height: 1000),
      );
      final decoded = img.decodeJpg(result.bytes)!;

      expect(decoded.width, 1600);
      expect(decoded.height, 800);
    });

    test('encodes small images as JPEG at quality 82', () async {
      final input = _pngImage();
      final decodedInput = img.bakeOrientation(img.decodeImage(input)!);
      final expected = Uint8List.fromList(
        img.encodeJpg(decodedInput, quality: 82),
      );

      final result = await _service().prepare(
        fileName: 'source.png',
        mimeType: 'image/png',
        bytes: input,
      );

      expect(result.bytes, expected);
    });

    test('rejects JPEG output larger than 2 MB', () async {
      final tooLarge = Uint8List(noteImageMaxBytes + 1);
      await expectLater(
        _service(imageProcessor: _FakeImageProcessor(tooLarge)).prepare(
          fileName: 'large.png',
          mimeType: 'image/png',
          bytes: _pngImage(),
        ),
        throwsA(
          isA<NoteMediaPreparationException>().having(
            (error) => error.message,
            'message',
            'Images must be 2 MB or smaller.',
          ),
        ),
      );
    });

    test('accepts JPEG output exactly 2 MB', () async {
      final exactlyAtLimit = Uint8List(noteImageMaxBytes);
      final result = await _service(
        imageProcessor: _FakeImageProcessor(exactlyAtLimit),
      ).prepare(
        fileName: 'limit.png',
        mimeType: 'image/png',
        bytes: _pngImage(),
      );

      expect(result.bytes.length, noteImageMaxBytes);
    });

    test('accepts MP4 and WebM at the inclusive video size limit', () async {
      for (final (name, mimeType, extension) in [
        ('clip.mp4', 'video/mp4', 'mp4'),
        ('clip.webm', 'video/webm', 'webm'),
      ]) {
        final bytes = Uint8List(noteVideoMaxBytes);
        final inspector = _FakeVideoDurationInspector(10);
        final result = await _service(videoInspector: inspector).prepare(
          fileName: name,
          mimeType: mimeType,
          bytes: bytes,
        );

        expect(result.bytes, same(bytes));
        expect(result.mediaType, NoteAttachmentMediaType.video);
        expect(result.extension, extension);
        expect(result.durationSeconds, 10);
        expect(inspector.receivedBytes, same(bytes));
        expect(inspector.receivedExtension, extension);
      }
    });

    test('rejects video larger than 5 MB before reading duration', () async {
      final inspector = _FakeVideoDurationInspector(2);
      await expectLater(
        _service(videoInspector: inspector).prepare(
          fileName: 'clip.mp4',
          mimeType: 'video/mp4',
          bytes: Uint8List(noteVideoMaxBytes + 1),
        ),
        throwsA(isA<NoteMediaPreparationException>()),
      );
      expect(inspector.receivedBytes, isNull);
    });

    test('rejects zero, non-finite, missing, and over-limit durations',
        () async {
      for (final duration in <double?>[
        0,
        -0.1,
        double.nan,
        double.infinity,
        null,
        10.001,
      ]) {
        await expectLater(
          _service(videoInspector: _FakeVideoDurationInspector(duration))
              .prepare(
            fileName: 'clip.webm',
            mimeType: 'video/webm',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
          throwsA(isA<NoteMediaPreparationException>()),
        );
      }
    });

    test('rejects unsupported types and empty files', () async {
      final service = _service();
      await expectLater(
        service.prepare(
          fileName: 'clip.mov',
          mimeType: 'video/quicktime',
          bytes: Uint8List.fromList([1]),
        ),
        throwsA(isA<NoteMediaPreparationException>()),
      );
      await expectLater(
        service.prepare(
          fileName: 'empty.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List(0),
        ),
        throwsA(isA<NoteMediaPreparationException>()),
      );
    });

    test('reports corrupt images and unreadable videos usefully', () async {
      await expectLater(
        _service().prepare(
          fileName: 'broken.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(isA<NoteMediaPreparationException>()),
      );

      await expectLater(
        _service(
          videoInspector: _FakeVideoDurationInspector(null)
            ..error = StateError('metadata unavailable'),
        ).prepare(
          fileName: 'broken.mp4',
          mimeType: 'video/mp4',
          bytes: Uint8List.fromList([1]),
        ),
        throwsA(
          isA<NoteMediaPreparationException>().having(
            (error) => error.message,
            'message',
            'This video could not be read.',
          ),
        ),
      );
    });
  });
}
