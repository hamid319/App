import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/constants/sizes.dart';
import '../../core/constants/typography.dart';

/// Outline of a paper ticket: a rounded rectangle with an ink rim and,
/// optionally, a perforation (two half-circle notches joined by a dashed
/// line) at [notchFromTop] or [notchFromBottom] pixels from that edge.
class TicketBorder extends ShapeBorder {
  const TicketBorder({
    this.color = const Color(0xFF221A14),
    this.width = AppSizes.edge,
    this.radius = AppSizes.radiusTicket,
    this.notchFromTop,
    this.notchFromBottom,
    this.notchRadius = AppSizes.notch,
  }) : assert(notchFromTop == null || notchFromBottom == null);

  final Color color;
  final double width;
  final double radius;
  final double? notchFromTop;
  final double? notchFromBottom;
  final double notchRadius;

  double? _notchY(Rect rect) {
    if (notchFromTop != null) return rect.top + notchFromTop!;
    if (notchFromBottom != null) return rect.bottom - notchFromBottom!;
    return null;
  }

  Path _outline(Rect rect) {
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final y = _notchY(rect);
    if (y == null) return body;
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(rect.left, y), radius: notchRadius))
      ..addOval(Rect.fromCircle(center: Offset(rect.right, y), radius: notchRadius));
    return Path.combine(PathOperation.difference, body, notches);
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _outline(rect.deflate(width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _outline(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (width <= 0) return;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    canvas.drawPath(_outline(rect.deflate(width / 2)), stroke);

    final y = _notchY(rect);
    if (y == null) return;
    const dash = 6.0, gap = 5.0;
    final dashes = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    var x = rect.left + notchRadius + gap;
    final end = rect.right - notchRadius - gap;
    while (x < end) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, end), y), dashes);
      x += dash + gap;
    }
  }

  @override
  ShapeBorder scale(double t) => TicketBorder(
        color: color,
        width: width * t,
        radius: radius * t,
        notchFromTop: notchFromTop == null ? null : notchFromTop! * t,
        notchFromBottom: notchFromBottom == null ? null : notchFromBottom! * t,
        notchRadius: notchRadius * t,
      );

  @override
  bool operator ==(Object other) =>
      other is TicketBorder &&
      other.color == color &&
      other.width == width &&
      other.radius == radius &&
      other.notchFromTop == notchFromTop &&
      other.notchFromBottom == notchFromBottom &&
      other.notchRadius == notchRadius;

  @override
  int get hashCode => Object.hash(
      color, width, radius, notchFromTop, notchFromBottom, notchRadius);
}

/// The hard, unblurred "print" shadow under raised tickets and buttons.
List<BoxShadow> printShadow(Color edge, {double offset = AppSizes.printShadow}) =>
    [BoxShadow(color: edge, offset: Offset(0, offset))];

/// A ticket-shaped surface with an ink rim. The base container for list
/// rows, swipe cards and info blocks in the "Ticket und Stempel" design.
///
/// [raised] adds the print shadow; use it for the one thing on a screen
/// that should feel tappable above the rest (the swipe card, a hero ticket).
class Ticket extends StatelessWidget {
  const Ticket({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.padding = EdgeInsets.zero,
    this.notchFromTop,
    this.notchFromBottom,
    this.raised = false,
    this.radius = AppSizes.radiusTicket,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double? notchFromTop;
  final double? notchFromBottom;
  final bool raised;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final edge = context.swipeColors.edge;
    final shape = TicketBorder(
      color: edge,
      radius: radius,
      notchFromTop: notchFromTop,
      notchFromBottom: notchFromBottom,
    );
    Widget body = Material(
      color: color ?? Theme.of(context).colorScheme.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (raised) {
      body = DecoratedBox(
        decoration: ShapeDecoration(shape: shape, shadows: printShadow(edge)),
        child: body,
      );
    }
    return body;
  }
}

/// A rubber stamp: rotated, outlined capitals. Used for LIKE / NOPE on the
/// swipe card, MUST SEE, MATCH and other moments worth a stamp.
class Stamp extends StatelessWidget {
  const Stamp({
    super.key,
    required this.text,
    required this.color,
    this.angle = -0.2,
    this.size = 28,
    this.filled = false,
  });

  final String text;
  final Color color;
  final double angle;
  final double size;

  /// Solid ink stamp (white-ish text on [color]) instead of an outline.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: size * 0.4,
          vertical: size * 0.08,
        ),
        decoration: BoxDecoration(
          color: filled ? color : null,
          border: Border.all(color: color, width: size * 0.11),
          borderRadius: BorderRadius.circular(size * 0.25),
        ),
        child: Text(
          text.toUpperCase(),
          style: AppTypography.stamp(filled ? bg : color)
              .copyWith(fontSize: size),
        ),
      ),
    );
  }
}

/// Round action with an ink rim and print shadow, for the swipe row and
/// other big single-purpose buttons.
class InkActionButton extends StatelessWidget {
  const InkActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.fill,
    this.iconColor,
    this.size = 56,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? fill;
  final Color? iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final edge = context.swipeColors.edge;
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.35,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill ?? scheme.surface,
            border: Border.all(color: edge, width: AppSizes.edge),
            boxShadow: enabled ? printShadow(edge) : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Icon(
                icon,
                size: size * 0.46,
                color: iconColor ?? scheme.onSurface,
                semanticLabel: tooltip,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Which pastel a [TagChip] uses.
enum ChipTone { neutral, mint, peach, sky, gold }

/// Small pastel pill with ink text, for place types, prices and statuses.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.tone = ChipTone.neutral,
    this.icon,
  });

  final String label;
  final ChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.swipeColors;
    final scheme = Theme.of(context).colorScheme;
    final fill = switch (tone) {
      ChipTone.neutral => scheme.surfaceContainerHigh,
      ChipTone.mint => c.mint,
      ChipTone.peach => c.peach,
      ChipTone.sky => c.sky,
      ChipTone.gold => c.gold.withValues(alpha: 0.35),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: scheme.onSurface),
            const SizedBox(width: 4),
          ],
          // Narrow tiles (sliders) shorten long types instead of overflowing.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small capitals label above a section ("MITGLIEDER", "ROUTE").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w800,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.space8),
      child: Row(
        children: [
          Expanded(child: Text(text.toUpperCase(), style: style)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Big round icon on a pastel disc with an ink rim, for empty, error and
/// success states.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.tone = ChipTone.peach,
    this.size = 88,
  });

  final IconData icon;
  final ChipTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.swipeColors;
    final fill = switch (tone) {
      ChipTone.neutral => Theme.of(context).colorScheme.surfaceContainerHigh,
      ChipTone.mint => c.mint,
      ChipTone.peach => c.peach,
      ChipTone.sky => c.sky,
      ChipTone.gold => c.gold,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: c.edge, width: AppSizes.edge),
        boxShadow: printShadow(c.edge),
      ),
      child: Icon(
        icon,
        size: size * 0.45,
        color: tone == ChipTone.gold
            ? const Color(0xFF221A14)
            : Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
