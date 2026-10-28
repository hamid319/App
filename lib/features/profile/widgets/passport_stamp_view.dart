import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../common/utils/passport_stamps.dart';

// Stamp ink on passport paper. The paper stays light in dark mode too
// (it is a physical object), so these do not follow the theme.
const _inks = [
  Color(0xFF1F2A6B), // navy
  Color(0xFFD9432E), // coral red
  Color(0xFF2E7D5B), // green
  Color(0xFF6A3FA0), // violet
  Color(0xFFA8700E), // amber brown
];

const _icons = [
  Icons.flight_rounded,
  Icons.train_rounded,
  Icons.directions_boat_rounded,
  Icons.location_city_rounded,
  Icons.landscape_rounded,
  Icons.beach_access_rounded,
  Icons.castle_outlined,
];

/// A city's passport stamp. Shape, ink, tilt and icon come from the
/// city id, so every city has its own look and keeps it.
class PassportStampView extends StatelessWidget {
  const PassportStampView({super.key, required this.stamp, this.size = 112});

  final PassportStamp stamp;
  final double size;

  @override
  Widget build(BuildContext context) {
    final seed = stamp.seed;
    final ink = _inks[seed % _inks.length];
    final shape = (seed >> 4) % 3; // 0 circle, 1 oval, 2 rectangle
    final angle = ((seed >> 8) % 41 - 20) / 100;
    final icon = _icons[(seed >> 14) % _icons.length];
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMd(locale).format(stamp.date);

    final radius = switch (shape) {
      0 => null,
      1 => BorderRadius.circular(size / 2),
      _ => BorderRadius.circular(size * 0.06),
    };
    BoxDecoration ring(double width) => BoxDecoration(
          shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: radius,
          border: Border.all(color: ink, width: width),
        );
    TextStyle style(double factor, {FontWeight? weight, double spacing = 0}) =>
        TextStyle(
          color: ink,
          fontSize: size * factor,
          fontWeight: weight,
          letterSpacing: spacing,
          height: 1.1,
        );

    return Semantics(
      label: '${stamp.cityName}, $date',
      child: Transform.rotate(
        angle: angle,
        // Uneven ink: one side pressed harder than the other, as with a
        // real rubber stamp. The light spot sits where the seed puts it.
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => RadialGradient(
            center: Alignment(
              ((seed >> 20) % 21 - 10) / 10,
              ((seed >> 26) % 21 - 10) / 10,
            ),
            radius: 1.1,
            colors: const [Color(0xF0FFFFFF), Color(0x8CFFFFFF)],
          ).createShader(r),
          child: Container(
            width: shape == 1 ? size * 1.4 : size,
            height: size,
            decoration: ring(size * 0.03),
            child: Container(
              margin: EdgeInsets.all(size * 0.04),
              padding: EdgeInsets.symmetric(horizontal: size * 0.12),
              decoration: ring(size * 0.012),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (stamp.countryCode.isNotEmpty)
                    Text(stamp.countryCode.toUpperCase(),
                        style: style(0.09,
                            weight: FontWeight.w700, spacing: size * 0.02)),
                  Icon(icon, color: ink, size: size * 0.2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(stamp.cityName.toUpperCase(),
                        maxLines: 1,
                        style: style(0.13, weight: FontWeight.w900)),
                  ),
                  SizedBox(height: size * 0.02),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(date.toUpperCase(), style: style(0.08)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Presses [child] onto the page like a rubber stamp after [delay]: it
/// drops from above, lands with a thud (haptic) and settles.
// One player for all stamps, kept for the app's lifetime (a few KB).
// Ambient audio: mixes with the user's music and stays quiet when the
// ring/silent switch is on.
AudioPlayer? _player;

void _thud() {
  final player = _player ??= AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency)
    ..setAudioContext(AudioContextConfig(respectSilence: true).build());
  player.stop().then((_) => player.play(AssetSource('sounds/stamp.wav')),
      // A missing sound must never break the stamping.
      onError: (_) {});
}

/// Without [play] it just shows [child]; the choice is made once, so
/// rebuilds during the animation do not cut it short.
class StampPress extends StatefulWidget {
  const StampPress({
    super.key,
    required this.child,
    required this.play,
    required this.delay,
    this.onPlay,
  });

  final Widget child;
  final bool play;
  final Duration delay;
  final VoidCallback? onPlay;

  @override
  State<StampPress> createState() => _StampPressState();
}

class _StampPressState extends State<StampPress>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  bool _landed = false;

  // Drop (0–0.55), squash on impact (0.55–0.75), settle (0.75–1).
  late final _scale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 2.4, end: 0.92)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 55),
    TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.04), weight: 20),
    TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 25),
  ]).animate(_c);

  @override
  void initState() {
    super.initState();
    if (!widget.play) {
      _c.value = 1;
      return;
    }
    widget.onPlay?.call();
    _c.addListener(() {
      if (!_landed && _c.value >= 0.55) {
        _landed = true;
        HapticFeedback.heavyImpact();
        _thud();
      }
    });
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Opacity(
        opacity: (_c.value / 0.4).clamp(0.0, 1.0),
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      child: widget.child,
    );
  }
}
