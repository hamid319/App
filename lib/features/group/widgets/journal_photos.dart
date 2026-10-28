import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../common/models/journal_entry.dart';
import '../../../l10n/l10n.dart';

/// One journal photo, cropped to fill its box.
class JournalImage extends StatelessWidget {
  const JournalImage({super.key, required this.photo, this.fit = BoxFit.cover});

  final JournalPhoto photo;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context).colorScheme.surfaceContainerHigh;
    return CachedNetworkImage(
      imageUrl: photo.url,
      fit: fit,
      placeholder: (_, __) => ColoredBox(color: fill),
      errorWidget: (_, __, ___) => ColoredBox(
        color: fill,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

/// Photos of an entry: one full width, two or three side by side, more as
/// a 2×2 grid whose last tile shows how many are left ("+2").
class JournalPhotoGrid extends StatelessWidget {
  const JournalPhotoGrid({super.key, required this.photos});

  final List<JournalPhoto> photos;

  static const _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget tile(int i, {String? more}) => Semantics(
          button: true,
          label: l10n.journalPhotoOf(i + 1, photos.length),
          child: GestureDetector(
            onTap: () => showJournalPhotoViewer(context, photos, initial: i),
            child: Stack(
              fit: StackFit.expand,
              children: [
                JournalImage(photo: photos[i]),
                if (more != null)
                  ColoredBox(
                    color: Colors.black45,
                    child: Center(
                      child: Text(more,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
        );

    Widget row(List<int> indexes, double height, {String? more}) => SizedBox(
          height: height,
          child: Row(
            children: [
              for (final (n, i) in indexes.indexed) ...[
                if (n > 0) const SizedBox(width: _gap),
                Expanded(
                  child: tile(i, more: n == indexes.length - 1 ? more : null),
                ),
              ],
            ],
          ),
        );

    if (photos.length == 1) {
      final p = photos.first;
      final ratio = p.width > 0 && p.height > 0 ? p.width / p.height : 4 / 3;
      // Very tall photos would fill the screen; keep them at 4:5.
      return AspectRatio(aspectRatio: ratio.clamp(0.8, 2.0), child: tile(0));
    }
    if (photos.length <= 3) {
      return row([for (var i = 0; i < photos.length; i++) i], 160);
    }
    final rest = photos.length - 4;
    return Column(
      children: [
        row([0, 1], 140),
        const SizedBox(height: _gap),
        row([2, 3], 140, more: rest > 0 ? '+$rest' : null),
      ],
    );
  }
}

/// Full-screen photos: swipe between them, pinch to zoom.
Future<void> showJournalPhotoViewer(
  BuildContext context,
  List<JournalPhoto> photos, {
  int initial = 0,
}) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.black,
    builder: (_) => _PhotoViewer(photos: photos, initial: initial),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.initial});

  final List<JournalPhoto> photos;
  final int initial;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _controller = PageController(initialPage: widget.initial);
  late int _page = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: Semantics(
                  image: true,
                  label: l10n.journalPhotoOf(i + 1, widget.photos.length),
                  child: JournalImage(
                      photo: widget.photos[i], fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  if (widget.photos.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '${_page + 1} / ${widget.photos.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.close,
                    color: Colors.white,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
