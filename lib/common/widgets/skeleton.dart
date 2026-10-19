import 'package:flutter/material.dart';
import '../../core/constants/sizes.dart';

/// Shimmer over placeholder shapes, shown while content loads. Loading that
/// looks like the coming content feels faster than a spinner in the middle.
/// Stays still when the device asks for reduced motion.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = Color.lerp(base, scheme.surface, 0.7)!;
    return Semantics(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) {
            final t = _controller.value * 3 - 1; // -1 .. 2
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(t - 1, -0.3),
                end: Alignment(t + 1, 0.3),
                colors: [base, highlight, base],
                stops: const [0.3, 0.5, 0.7],
              ).createShader(bounds),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// One placeholder shape. Use inside a [Skeleton].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = AppSizes.radiusXs,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A list of rows with a square thumbnail and two text lines: favorites,
/// groups, session history, results, profile.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6, this.thumbnail = true});

  final int count;
  final bool thumbnail;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSizes.screenEdge),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: AppSizes.space16),
        itemBuilder: (_, i) => Row(
          children: [
            if (thumbnail) ...[
              const SkeletonBox(
                width: 56,
                height: 56,
                radius: AppSizes.radiusSm,
              ),
              const SizedBox(width: AppSizes.space12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vary the widths so rows don't look like a barcode.
                  FractionallySizedBox(
                    widthFactor: i.isEven ? 0.75 : 0.6,
                    child: const SkeletonBox(height: 14),
                  ),
                  const SizedBox(height: AppSizes.space8),
                  FractionallySizedBox(
                    widthFactor: i.isEven ? 0.45 : 0.55,
                    child: const SkeletonBox(height: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big image on top, title and text lines below: place details.
class SkeletonDetail extends StatelessWidget {
  const SkeletonDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: const [
          SkeletonBox(height: 300, radius: 0),
          Padding(
            padding: EdgeInsets.all(AppSizes.screenEdge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.7,
                  child: SkeletonBox(height: 26),
                ),
                SizedBox(height: AppSizes.space12),
                FractionallySizedBox(
                  widthFactor: 0.45,
                  child: SkeletonBox(height: 13),
                ),
                SizedBox(height: AppSizes.groupGap),
                SkeletonBox(height: 13),
                SizedBox(height: AppSizes.space8),
                SkeletonBox(height: 13),
                SizedBox(height: AppSizes.space8),
                FractionallySizedBox(
                  widthFactor: 0.8,
                  child: SkeletonBox(height: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fills an image slot while the picture downloads.
class SkeletonImage extends StatelessWidget {
  const SkeletonImage({super.key, this.radius = 0});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: SkeletonBox(
        width: double.infinity,
        height: double.infinity,
        radius: radius,
      ),
    );
  }
}
