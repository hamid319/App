import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/place_model.dart';
import '../../../common/widgets/member_avatar.dart';
import '../../../common/widgets/place_photo.dart';
import '../../../common/widgets/ticket.dart';
import '../../../app/theme.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/constants/typography.dart';
import '../../../l10n/l10n.dart';
import '../logic/group_controller.dart';

/// Full-screen "It's a match!" moment for the group's top place after a
/// session ends. [onOpenPlace] runs after the overlay has closed.
Future<void> showMatchCelebration(
  BuildContext context, {
  required PlaceModel place,
  required int likes,
  required List<String> participants,
  required VoidCallback onOpenPlace,
}) {
  HapticFeedback.mediumImpact();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (dialogContext, _, __) => _MatchCelebration(
      place: place,
      likes: likes,
      participants: participants,
      onOpenPlace: () {
        Navigator.of(dialogContext).pop();
        onOpenPlace();
      },
      onClose: () => Navigator.of(dialogContext).pop(),
    ),
    transitionBuilder: (_, animation, __, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.96, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
  );
}

class _MatchCelebration extends StatelessWidget {
  const _MatchCelebration({
    required this.place,
    required this.likes,
    required this.participants,
    required this.onOpenPlace,
    required this.onClose,
  });

  final PlaceModel place;
  final int likes;
  final List<String> participants;
  final VoidCallback onOpenPlace;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = scheme.onSurface;

    return Material(
      // Opaque paper: the results list loads behind it and must not show
      // through.
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          if (!reduceMotion) const Positioned.fill(child: _Confetti()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.space24),
              child: Column(
                children: [
                  const Spacer(),
                  _MatchArt(place: place, participants: participants),
                  const SizedBox(height: AppSizes.space32),
                  Text(
                    l10n.matchTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.display(size: 38, color: ink),
                  ),
                  const SizedBox(height: AppSizes.space12),
                  Text(
                    l10n.matchBody(
                      place.nameFor(Localizations.localeOf(context).languageCode),
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSizes.space12),
                  TagChip(
                    label: l10n.matchVotes(likes, participants.length),
                    tone: ChipTone.peach,
                    icon: Icons.favorite_rounded,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onOpenPlace,
                      child: Text(l10n.matchOpenPlace),
                    ),
                  ),
                  const SizedBox(height: AppSizes.space8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onClose,
                      child: Text(l10n.matchSeeResults),
                    ),
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

/// The place photo, tilted, with up to three member avatars around it and
/// a heart badge below.
class _MatchArt extends ConsumerWidget {
  const _MatchArt({required this.place, required this.participants});

  final PlaceModel place;
  final List<String> participants;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ring = Theme.of(context).scaffoldBackgroundColor;
    final edge = context.swipeColors.edge;
    final shown = participants.take(3).toList();
    const spots = [
      Alignment(-1, 0.85),
      Alignment(1, 0.55),
      Alignment(0.62, -1),
    ];
    return SizedBox(
      width: 240,
      height: 200,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.05,
            child: SizedBox(
              width: 150,
              height: 190,
              child: Ticket(
                raised: true,
                child: PlacePhoto(place: place),
              ),
            ),
          ),
          for (final (i, uid) in shown.indexed)
            Align(
              alignment: spots[i],
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: edge, width: AppSizes.edge),
                ),
                child: MemberAvatar(
                  id: uid,
                  name: friendlyMemberName(
                          ref.watch(groupMemberNameProvider(uid)).value) ??
                      '?',
                  size: 48,
                  borderColor: ring,
                ),
              ),
            ),
          Positioned(
            bottom: -22,
            child: Stamp(
              text: context.l10n.matchStamp,
              color: edge,
              size: 22,
              angle: -0.14,
              filled: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// One burst of falling confetti, played once.
class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  final _pieces = List.generate(70, (i) => _Piece(math.Random(i * 7919)));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swipeColors;
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(
          _pieces,
          _controller,
          [scheme.primary, c.gold, c.edge, c.sky, c.mint],
        ),
      ),
    );
  }
}

class _Piece {
  _Piece(math.Random r)
      : x = r.nextDouble(),
        delay = r.nextDouble() * 0.35,
        speed = 0.6 + r.nextDouble() * 0.6,
        drift = (r.nextDouble() - 0.5) * 0.25,
        spin = (r.nextDouble() - 0.5) * 12,
        colorIndex = r.nextInt(1 << 16);

  final double x, delay, speed, drift, spin;

  /// Picks one of the painter's colours.
  final int colorIndex;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.progress, this.colors)
      : super(repaint: progress);

  final List<_Piece> pieces;
  final Animation<double> progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final t = ((progress.value - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t == 0) continue;
      final y = -20 + t * p.speed * (size.height + 40);
      final x = (p.x + p.drift * t) * size.width;
      paint.color = colors[p.colorIndex % colors.length]
          .withValues(alpha: 1 - t * 0.6);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.spin * t)
        ..drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-3.5, -6, 7, 12),
            const Radius.circular(2),
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => false;
}
