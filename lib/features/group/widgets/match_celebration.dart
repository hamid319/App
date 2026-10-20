import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/models/place_model.dart';
import '../../../common/widgets/member_avatar.dart';
import '../../../common/widgets/place_photo.dart';
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

/// Warm gradient that reads as a celebration in light and dark mode alike.
const _matchGradient = RadialGradient(
  center: Alignment(0, -0.4),
  radius: 1.2,
  colors: [Color(0xF5FF7A45), Color(0xF0FF3D6E), Color(0xF76E2878)],
  stops: [0, 0.55, 1],
);

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
    final body = Theme.of(context).textTheme.bodyLarge;

    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: _matchGradient),
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
                      style: AppTypography.display(
                        size: 38,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSizes.space12),
                    Text(
                      l10n.matchBody(place.name),
                      textAlign: TextAlign.center,
                      style: body?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: AppSizes.space12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            l10n.matchVotes(likes, participants.length),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onOpenPlace,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFC2264F),
                        ),
                        child: Text(l10n.matchOpenPlace),
                      ),
                    ),
                    const SizedBox(height: AppSizes.space8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onClose,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Text(l10n.matchSeeResults),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    const ring = Colors.white;
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
            child: Container(
              width: 150,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(color: ring, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x73000000),
                    blurRadius: 30,
                    spreadRadius: -10,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusLg - 4),
                child: PlacePhoto(place: place),
              ),
            ),
          ),
          for (final (i, uid) in shown.indexed)
            Align(
              alignment: spots[i],
              child: MemberAvatar(
                id: uid,
                name: ref.watch(groupMemberNameProvider(uid)).value ?? '?',
                size: 48,
                borderColor: ring,
              ),
            ),
          Positioned(
            bottom: -18,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0x40000000), blurRadius: 14),
                ],
              ),
              child: const Icon(
                Icons.favorite,
                color: Color(0xFFFF3D6E),
                size: 22,
              ),
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
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(_pieces, _controller),
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
        color = _colors[r.nextInt(_colors.length)];

  static const _colors = [
    Color(0xFFFFFFFF),
    Color(0xFFFFD166),
    Color(0xFF2BD4A4),
    Color(0xFF7CC7FF),
    Color(0xFFFFB3C6),
  ];

  final double x, delay, speed, drift, spin;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.progress) : super(repaint: progress);

  final List<_Piece> pieces;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final t = ((progress.value - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t == 0) continue;
      final y = -20 + t * p.speed * (size.height + 40);
      final x = (p.x + p.drift * t) * size.width;
      paint.color = p.color.withValues(alpha: 1 - t * 0.6);
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
