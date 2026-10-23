import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../common/models/place_model.dart';
import '../../../common/utils/place_type_labels.dart';
import '../../../common/widgets/place_photo.dart';
import '../../../common/widgets/skeleton.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/constants/typography.dart';
import '../../../l10n/l10n.dart';

/// The swipe stack used by Discover (solo) and group sessions: the current
/// card on top, the next place's photo waiting behind it, LIKE / NOPE stamps
/// that follow the drag, and the action row underneath.
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.place,
    required this.onLike,
    required this.onSkip,
    required this.onDetail,
    this.nextPlace,
    this.onUndo,
    this.canUndo = false,
  });

  final PlaceModel place;
  final PlaceModel? nextPlace;
  final VoidCallback onLike;
  final VoidCallback onSkip;
  final VoidCallback onDetail;

  /// Null hides the undo button entirely (group sessions).
  final VoidCallback? onUndo;

  /// Whether there is a swipe to take back; false greys the button out.
  final bool canUndo;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin {
  /// Share of the card width a drag must pass to count as a swipe.
  static const double _threshold = 0.3;
  static const double _maxRotation = 0.22;

  late final AnimationController _anim;
  Offset _drag = Offset.zero;
  bool _animating = false;
  bool _pastThreshold = false;
  double _width = 1;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.id != widget.place.id) {
      _anim.stop();
      _drag = Offset.zero;
      _animating = false;
      _pastThreshold = false;
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_animating) return;
    setState(() => _drag += d.delta);
    final past = _drag.dx.abs() > _width * _threshold;
    if (past && !_pastThreshold) HapticFeedback.lightImpact();
    _pastThreshold = past;
  }

  void _onPanEnd(DragEndDetails d) {
    if (_animating) return;
    final vx = d.velocity.pixelsPerSecond.dx;
    final flung = vx.abs() > 800 && vx.sign == _drag.dx.sign;
    if (_drag.dx.abs() > _width * _threshold || flung) {
      _flyOut(toRight: _drag.dx > 0);
    } else {
      _snapBack();
    }
  }

  void _animateTo(
    Offset target,
    Duration duration,
    Curve curve, {
    VoidCallback? onDone,
  }) {
    _animating = true;
    final tween = Tween(begin: _drag, end: target)
        .chain(CurveTween(curve: curve));
    void tick() => setState(() => _drag = tween.evaluate(_anim));
    _anim
      ..duration = duration
      ..addListener(tick);
    _anim.forward(from: 0).whenComplete(() {
      _anim.removeListener(tick);
      if (!mounted) return;
      _animating = false;
      onDone?.call();
    });
  }

  void _snapBack() => _animateTo(
        Offset.zero,
        AppSizes.snapBack,
        Curves.easeOutBack,
        onDone: () => _pastThreshold = false,
      );

  void _flyOut({required bool toRight}) {
    final target = Offset(
      (toRight ? 1 : -1) * _width * 1.6,
      _drag.dy + 40,
    );
    _animateTo(target, AppSizes.cardOut, Curves.easeIn, onDone: () {
      toRight ? widget.onLike() : widget.onSkip();
      // The parent swaps in the next place; until it does, keep the old card
      // off-screen instead of flashing it back in the middle.
    });
  }

  void _buttonSwipe({required bool toRight}) {
    if (_animating) return;
    HapticFeedback.selectionClick();
    _drag = Offset(toRight ? 8 : -8, 0);
    _flyOut(toRight: toRight);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.swipeColors;
    final l10n = context.l10n;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.cardInset,
              AppSizes.space4,
              AppSizes.cardInset,
              0,
            ),
            child: LayoutBuilder(builder: (context, box) {
              _width = box.maxWidth;
              final progress = (_drag.dx / (_width * _threshold)).clamp(-1.0, 1.0);
              return Stack(
                children: [
                  if (widget.nextPlace != null)
                    Positioned.fill(
                      child: _BackCard(
                        place: widget.nextPlace!,
                        // The waiting card rises as the top card leaves.
                        lift: progress.abs(),
                      ),
                    ),
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      // Replays when a new card comes up (or one is undone).
                      key: ValueKey(widget.place.id),
                      tween: Tween(begin: AppSizes.backCardScale, end: 1),
                      duration: AppSizes.nextCardUp,
                      curve: Curves.easeOut,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: GestureDetector(
                        onTap: widget.onDetail,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: Transform.translate(
                          offset: _drag,
                          child: Transform.rotate(
                            angle: _drag.dx / _width * _maxRotation,
                            child: _CardFace(
                              place: widget.place,
                              likeOpacity: progress.clamp(0.0, 1.0),
                              nopeOpacity: (-progress).clamp(0.0, 1.0),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenEdge,
            AppSizes.space16,
            AppSizes.screenEdge,
            AppSizes.space12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.onUndo != null) ...[
                InkActionButton(
                  size: 46,
                  icon: Icons.undo_rounded,
                  fill: colors.gold,
                  iconColor: _onGold,
                  tooltip: l10n.undo,
                  onPressed:
                      _animating || !widget.canUndo ? null : widget.onUndo,
                ),
                const SizedBox(width: AppSizes.space16),
              ],
              InkActionButton(
                size: 64,
                icon: Icons.close_rounded,
                iconColor: colors.nope,
                tooltip: l10n.skip,
                onPressed: () => _buttonSwipe(toRight: false),
              ),
              const SizedBox(width: AppSizes.space16),
              InkActionButton(
                size: 64,
                icon: Icons.favorite_rounded,
                fill: colors.like,
                iconColor: Theme.of(context).colorScheme.onPrimary,
                tooltip: l10n.like,
                onPressed: () => _buttonSwipe(toRight: true),
              ),
              const SizedBox(width: AppSizes.space16),
              InkActionButton(
                size: 46,
                icon: Icons.info_outline_rounded,
                tooltip: l10n.details,
                onPressed: widget.onDetail,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ink on the gold undo button in both modes.
const _onGold = Color(0xFF221A14);

/// Height of the ticket stub under the perforation: name, one line of
/// description and the tags.
const double _stubHeight = 140;

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.place,
    required this.likeOpacity,
    required this.nopeOpacity,
  });

  final PlaceModel place;
  final double likeOpacity;
  final double nopeOpacity;

  @override
  Widget build(BuildContext context) {
    final colors = context.swipeColors;
    final theme = Theme.of(context);
    final tags = placeTypeLabels(context.l10n, place.types).take(3).toList();
    final lang = Localizations.localeOf(context).languageCode;
    final description = place.descriptionFor(lang)?.trim() ?? '';
    const tones = [ChipTone.mint, ChipTone.sky, ChipTone.peach];

    return Ticket(
      raised: true,
      notchFromBottom: _stubHeight,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: placePhotoHeroTag(place.id),
                  child: PlacePhoto(place: place),
                ),
                Positioned(
                  top: 28,
                  left: 18,
                  child: _FadingStamp(
                    opacity: likeOpacity,
                    child: Stamp(
                      text: context.l10n.likeStamp,
                      color: colors.like,
                      filled: true,
                      angle: -0.22,
                    ),
                  ),
                ),
                Positioned(
                  top: 28,
                  right: 18,
                  child: _FadingStamp(
                    opacity: nopeOpacity,
                    child: Stamp(
                      text: context.l10n.nopeStamp,
                      color: colors.nope,
                      filled: true,
                      angle: 0.22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: _stubHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.space16 + 4,
                AppSizes.space16 + 2,
                AppSizes.space16 + 4,
                AppSizes.space12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.nameFor(lang),
                    style: AppTypography.cardTitle()
                        .copyWith(color: theme.colorScheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.space4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (i, t) in tags.indexed)
                          TagChip(label: t, tone: tones[i % tones.length]),
                      ],
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

class _BackCard extends StatelessWidget {
  const _BackCard({required this.place, required this.lift});

  final PlaceModel place;

  /// 0 = resting behind, 1 = top card has passed the swipe threshold.
  final double lift;

  @override
  Widget build(BuildContext context) {
    final scale = AppSizes.backCardScale + (1 - AppSizes.backCardScale) * lift;
    return Transform.translate(
      offset: Offset(0, 14 * (1 - lift)),
      child: Transform.scale(
        scale: scale,
        child: Ticket(
          notchFromBottom: _stubHeight,
          child: Column(
            children: [
              Expanded(child: PlacePhoto(place: place)),
              const SizedBox(height: _stubHeight),
            ],
          ),
        ),
      ),
    );
  }
}

class _FadingStamp extends StatelessWidget {
  const _FadingStamp({required this.opacity, required this.child});

  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    // Stamps land a little bigger, like they are pressed onto the ticket.
    return Opacity(
      opacity: opacity,
      child: Transform.scale(scale: 1.25 - 0.25 * opacity, child: child),
    );
  }
}

/// Placeholder in the shape of the deck while places load.
class SwipeDeckSkeleton extends StatelessWidget {
  const SwipeDeckSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Column(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.cardInset,
                AppSizes.space4,
                AppSizes.cardInset,
                0,
              ),
              child: SkeletonBox(
                width: double.infinity,
                height: double.infinity,
                radius: AppSizes.radiusTicket,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenEdge,
              AppSizes.space16,
              AppSizes.screenEdge,
              AppSizes.space12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (i, size) in const [46.0, 64.0, 64.0, 46.0].indexed) ...[
                  if (i > 0) const SizedBox(width: AppSizes.space16),
                  SkeletonBox(width: size, height: size, radius: size / 2),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
