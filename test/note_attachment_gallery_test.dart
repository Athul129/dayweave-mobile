import 'package:dayweave_mobile/features/notes/presentation/note_attachment_gallery.dart';
import 'package:dayweave_mobile/models/note_attachment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

NoteAttachment _attachment(
  String id, {
  NoteAttachmentMediaType type = NoteAttachmentMediaType.image,
  String? url,
}) =>
    NoteAttachment(
      id: id,
      noteId: 'note-1',
      userId: 'user-1',
      storagePath:
          'user-1/note-1/$id.${type == NoteAttachmentMediaType.image ? 'jpg' : 'mp4'}',
      mediaType: type,
      mimeType:
          type == NoteAttachmentMediaType.image ? 'image/jpeg' : 'video/mp4',
      fileSize: 12,
      durationSeconds: type == NoteAttachmentMediaType.video ? 8 : null,
      createdAt: null,
      url: url ?? 'https://media.invalid/$id',
    );

Widget _app(Widget child) => MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(child: child),
        ),
      ),
    );

void main() {
  testWidgets('image tap opens a zoomable full-screen viewer', (tester) async {
    await tester.pumpWidget(_app(NoteAttachmentGallery(
      attachments: [_attachment('image-1')],
      onDelete: (_) async {},
      onRefreshUrl: () {},
    )));
    await tester.pumpAndSettle();

    final imageRect = tester.getRect(
      find.byKey(const Key('attachment-image-image-1')),
    );
    await tester.tapAt(imageRect.topCenter + const Offset(0, 12));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fullscreen-image-viewer')), findsOneWidget);
    expect(find.byKey(const Key('close-image-viewer')), findsOneWidget);
    await tester.tap(find.byKey(const Key('close-image-viewer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fullscreen-image-viewer')), findsNothing);
  });

  testWidgets('gallery navigates between image and video attachments',
      (tester) async {
    await tester.pumpWidget(_app(NoteAttachmentGallery(
      attachments: [
        _attachment('image-1'),
        _attachment('video-1', type: NoteAttachmentMediaType.video),
      ],
      onDelete: (_) async {},
      onRefreshUrl: () {},
      videoBuilder: (context, attachment, refresh) => const ColoredBox(
        color: Colors.black,
        child: Center(child: Text('Video playback surface')),
      ),
    )));
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Next attachment'));
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Video playback surface'), findsOneWidget);
    expect(find.text('Video · 8s'), findsOneWidget);
  });

  testWidgets('expired image URL exposes a refresh action', (tester) async {
    var refreshes = 0;
    await tester.pumpWidget(_app(NoteAttachmentGallery(
      attachments: [_attachment('expired')],
      onDelete: (_) async {},
      onRefreshUrl: () => refreshes++,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Refresh media'), findsOneWidget);
    await tester.tap(find.text('Refresh media'));
    expect(refreshes, 1);
  });

  testWidgets('video player exposes loading and recoverable error states',
      (tester) async {
    var refreshes = 0;
    await tester.pumpWidget(_app(NoteAttachmentVideoPlayer(
      attachment: _attachment(
        'video-error',
        type: NoteAttachmentMediaType.video,
      ),
      onRefreshUrl: () => refreshes++,
    )));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Media could not be loaded.'), findsOneWidget);
    await tester.tap(find.text('Refresh media'));
    expect(refreshes, 1);
  });

  testWidgets('remove action targets the currently selected attachment',
      (tester) async {
    NoteAttachment? removed;
    final attachments = [
      _attachment('first'),
      _attachment('second'),
    ];
    await tester.pumpWidget(_app(NoteAttachmentGallery(
      attachments: attachments,
      onDelete: (attachment) async => removed = attachment,
      onRefreshUrl: () {},
    )));
    await tester.pump();
    await tester.tap(find.byTooltip('Next attachment'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remove-attachment')));

    expect(removed, same(attachments.last));
  });
}
