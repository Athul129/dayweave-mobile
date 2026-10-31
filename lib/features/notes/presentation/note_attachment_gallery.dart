import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/dayweave_theme.dart';
import '../../../models/note_attachment.dart';

typedef NoteAttachmentVideoBuilder = Widget Function(
  BuildContext context,
  NoteAttachment attachment,
  VoidCallback refreshUrl,
);

class NoteAttachmentGallery extends StatefulWidget {
  const NoteAttachmentGallery({
    required this.attachments,
    required this.onDelete,
    required this.onRefreshUrl,
    this.isDeleting = false,
    this.videoBuilder,
    super.key,
  });

  final List<NoteAttachment> attachments;
  final Future<void> Function(NoteAttachment attachment) onDelete;
  final VoidCallback onRefreshUrl;
  final bool isDeleting;
  @visibleForTesting
  final NoteAttachmentVideoBuilder? videoBuilder;

  @override
  State<NoteAttachmentGallery> createState() => _NoteAttachmentGalleryState();
}

class _NoteAttachmentGalleryState extends State<NoteAttachmentGallery> {
  late final PageController _pageController = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(covariant NoteAttachmentGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.attachments.length) {
      _index = widget.attachments.isEmpty ? 0 : widget.attachments.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _pageController.hasClients &&
            widget.attachments.isNotEmpty) {
          _pageController.jumpToPage(_index);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attachments.isEmpty) return const SizedBox.shrink();
    final attachment = widget.attachments[_index.clamp(
      0,
      widget.attachments.length - 1,
    )];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _eyebrow(context, 'ATTACHMENTS')),
            Text(
              '${_index + 1} / ${widget.attachments.length}',
              key: const Key('attachment-page-count'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: DayweaveRadii.sm,
          child: SizedBox(
            height: 230,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  key: const Key('attachment-gallery'),
                  controller: _pageController,
                  itemCount: widget.attachments.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) {
                    final item = widget.attachments[index];
                    return item.mediaType == NoteAttachmentMediaType.image
                        ? _ImageAttachmentPage(
                            attachment: item,
                            onRefreshUrl: widget.onRefreshUrl,
                          )
                        : (widget.videoBuilder?.call(
                              context,
                              item,
                              widget.onRefreshUrl,
                            ) ??
                            NoteAttachmentVideoPlayer(
                              key: ValueKey('${item.id}:${item.url}'),
                              attachment: item,
                              onRefreshUrl: widget.onRefreshUrl,
                            ));
                  },
                ),
                if (widget.attachments.length > 1) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _galleryButton(
                      icon: Icons.chevron_left,
                      label: 'Previous attachment',
                      onPressed: () => _move(-1),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _galleryButton(
                      icon: Icons.chevron_right,
                      label: 'Next attachment',
                      onPressed: () => _move(1),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: Text(
                attachment.mediaType == NoteAttachmentMediaType.video
                    ? 'Video${attachment.durationSeconds == null ? '' : ' · ${attachment.durationSeconds}s'}'
                    : 'Image',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (widget.attachments.length > 1)
              Wrap(
                spacing: 5,
                children: [
                  for (var index = 0;
                      index < widget.attachments.length;
                      index++)
                    Semantics(
                      button: true,
                      label:
                          '${widget.attachments[index].mediaType == NoteAttachmentMediaType.image ? 'Image' : 'Video'} ${index + 1} of ${widget.attachments.length}',
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: InkWell(
                          key: Key('attachment-dot-$index'),
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => _jumpTo(index),
                          child: Center(
                            child: CircleAvatar(
                              radius: 4,
                              backgroundColor: index == _index
                                  ? DayweaveColors.marigold
                                  : DayweaveColors.line,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            TextButton.icon(
              key: const Key('remove-attachment'),
              onPressed:
                  widget.isDeleting ? null : () => widget.onDelete(attachment),
              icon: widget.isDeleting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline, size: 17),
              label: const Text('Remove'),
              style:
                  TextButton.styleFrom(foregroundColor: DayweaveColors.coral),
            ),
          ],
        ),
      ],
    );
  }

  void _move(int delta) {
    final next = (_index + delta + widget.attachments.length) %
        widget.attachments.length;
    _jumpTo(next);
  }

  void _jumpTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }
}

class _ImageAttachmentPage extends StatelessWidget {
  const _ImageAttachmentPage({
    required this.attachment,
    required this.onRefreshUrl,
  });

  final NoteAttachment attachment;
  final VoidCallback onRefreshUrl;

  @override
  Widget build(BuildContext context) {
    final url = attachment.url;
    if (url == null) return const _MediaUnavailable();
    return Material(
      color: DayweaveColors.bluePaper,
      child: InkWell(
        key: Key('attachment-image-${attachment.id}'),
        onTap: () =>
            _openImageViewer(context, url, attachment.id, onRefreshUrl),
        child: Image.network(
          url,
          key: ValueKey('${attachment.id}:$url'),
          cacheWidth: _decodePixels(
            MediaQuery.sizeOf(context).width,
            MediaQuery.devicePixelRatioOf(context),
          ),
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(
                  child: CircularProgressIndicator(
                    color: DayweaveColors.marigold,
                    strokeWidth: 2,
                  ),
                ),
          errorBuilder: (context, error, stackTrace) =>
              _MediaUnavailable(onRetry: onRefreshUrl),
        ),
      ),
    );
  }
}

class NoteAttachmentVideoPlayer extends StatefulWidget {
  const NoteAttachmentVideoPlayer({
    required this.attachment,
    required this.onRefreshUrl,
    super.key,
  });

  final NoteAttachment attachment;
  final VoidCallback onRefreshUrl;

  @override
  State<NoteAttachmentVideoPlayer> createState() =>
      _NoteAttachmentVideoPlayerState();
}

class _NoteAttachmentVideoPlayerState extends State<NoteAttachmentVideoPlayer> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant NoteAttachmentVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.url != widget.attachment.url) _initialize();
  }

  Future<void> _initialize() async {
    final previous = _controller;
    _controller = null;
    _error = null;
    if (mounted) setState(() {});
    await previous?.dispose();
    final url = widget.attachment.url;
    if (url == null) {
      if (mounted) setState(() => _error = StateError('Video URL unavailable'));
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      if (mounted && identical(_controller, controller)) setState(() {});
    } catch (error) {
      if (mounted && identical(_controller, controller)) {
        setState(() => _error = error);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null) {
      return _MediaUnavailable(onRetry: widget.onRefreshUrl);
    }
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: DayweaveColors.ink,
        child: Center(
          child: CircularProgressIndicator(color: DayweaveColors.marigold),
        ),
      );
    }
    return ColoredBox(
      color: DayweaveColors.ink,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          IconButton.filledTonal(
            key: const Key('video-play-pause'),
            onPressed: _togglePlayback,
            icon: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: DayweaveColors.marigold,
                bufferedColor: DayweaveColors.line,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }
}

class _MediaUnavailable extends StatelessWidget {
  const _MediaUnavailable({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: DayweaveColors.bluePaper,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined,
                  color: DayweaveColors.inkSoft, size: 30),
              const SizedBox(height: 6),
              Text(
                'Media could not be loaded.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh media'),
                ),
              ],
            ],
          ),
        ),
      );
}

Widget _galleryButton({
  required IconData icon,
  required String label,
  required VoidCallback onPressed,
}) =>
    Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: DayweaveColors.ink.withValues(alpha: .68),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: label,
          onPressed: onPressed,
          color: Colors.white,
          icon: Icon(icon),
        ),
      ),
    );

Widget _eyebrow(BuildContext context, String text) => Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
    );

Future<void> _openImageViewer(
  BuildContext context,
  String url,
  String attachmentId,
  VoidCallback onRefreshUrl,
) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close image viewer',
      barrierColor: Colors.black.withValues(alpha: .94),
      pageBuilder: (dialogContext, _, __) => Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: InteractiveViewer(
                    key: const Key('fullscreen-image-viewer'),
                    minScale: .8,
                    maxScale: 4,
                    child: Image.network(
                      url,
                      key: ValueKey('fullscreen:$attachmentId:$url'),
                      cacheWidth: _decodePixels(
                        MediaQuery.sizeOf(dialogContext).width,
                        MediaQuery.devicePixelRatioOf(dialogContext),
                      ),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          _MediaUnavailable(
                        onRetry: () {
                          Navigator.of(dialogContext).pop();
                          onRefreshUrl();
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  key: const Key('close-image-viewer'),
                  tooltip: 'Close image viewer',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );

int _decodePixels(double logicalPixels, double devicePixelRatio) =>
    (logicalPixels * devicePixelRatio).ceil();
