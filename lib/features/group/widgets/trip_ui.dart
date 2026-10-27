import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/models/group_model.dart';
import '../../../common/utils/trip_dates.dart';
import '../../../common/widgets/member_avatar.dart';
import '../../../common/widgets/place_photo.dart';
import '../logic/group_controller.dart';
import '../../../l10n/l10n.dart';
import '../logic/trip_controller.dart';

/// iOS-style building blocks of the trip screens: inset groups, section
/// headers, the floating primary pill, glass buttons over photos.

/// White rounded group with hairline separators between [children].
class InsetGroup extends StatelessWidget {
  const InsetGroup({
    super.key,
    required this.children,
    this.separatorIndent = 14,
    this.radius = 16,
  });

  final List<Widget> children;
  final double separatorIndent;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Material(
        color: scheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0)
                Padding(
                  padding: EdgeInsets.only(left: separatorIndent),
                  child: Divider(
                    height: 0.5,
                    thickness: 0.5,
                    color: scheme.outlineVariant,
                  ),
                ),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// Plain white rounded card.
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.radius = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Bold group title with an optional tinted action on the right.
class TripSectionHeader extends StatelessWidget {
  const TripSectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: text.titleLarge)),
          if (action != null)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  action!,
                  style: text.labelLarge?.copyWith(color: scheme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The screen's one primary action: a tinted 54 pt pill with a soft shadow,
/// meant to float above the content at the bottom.
class FloatingPrimaryButton extends StatelessWidget {
  const FloatingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !loading;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          child: loading
              ? SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: scheme.onPrimary,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Places [button] at the bottom of a Stack, above the home indicator.
class BottomFloat extends StatelessWidget {
  const BottomFloat({super.key, required this.button});

  final Widget button;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 0,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 16),
        child: button,
      ),
    );
  }
}

/// Round translucent button over a photo or map (back, invite).
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.label,
    this.opacity = 0.75,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final String? label;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: tooltip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: scheme.surface.withValues(alpha: opacity),
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: label == null ? 0 : 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: label == null ? 44 : null,
                        child: Icon(icon, size: 20, color: scheme.onSurface),
                      ),
                      if (label != null) ...[
                        const SizedBox(width: 6),
                        Text(label!, style: text.labelLarge),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One segment of [TripSegmentedControl].
class TripSegment {
  const TripSegment(this.label, {this.badge, this.enabled = true});

  final String label;

  /// Small note after the label, e.g. "soon" on a disabled segment.
  final String? badge;
  final bool enabled;
}

/// iOS segmented control: grey track, the selected segment as a white
/// raised pill. Disabled segments are dimmed but still tappable, so they
/// can explain themselves.
class TripSegmentedControl extends StatelessWidget {
  const TripSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
  });

  final List<TripSegment> segments;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final (i, segment) in segments.indexed)
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                enabled: segment.enabled,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: i == selected
                        ? BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          )
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            segment.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium?.copyWith(
                              fontSize: 14,
                              fontWeight: i == selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: segment.enabled
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        if (segment.badge != null) ...[
                          const SizedBox(width: 3),
                          Text(
                            segment.badge!,
                            style: text.labelSmall?.copyWith(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Photo of the trip's city (its best-known curated place), or a tinted
/// gradient for cities without photos.
class TripCover extends ConsumerWidget {
  const TripCover({super.key, required this.group});

  final GroupModel group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places =
        ref.watch(tripCityPlacesProvider(tripCityKey(group))).value ?? const [];
    final withPhoto = places.where((p) => p.imageUrls.isNotEmpty);
    final cover = withPhoto.isNotEmpty
        ? withPhoto.first
        : (places.isNotEmpty ? places.first : null);
    if (cover != null) return PlacePhoto(place: cover);
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.55),
            scheme.primary.withValues(alpha: 0.20),
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.luggage_rounded,
            size: 48, color: scheme.onPrimary.withValues(alpha: 0.9)),
      ),
    );
  }
}

/// A member's name for display, never an email; [fallback] while unknown.
String memberName(WidgetRef ref, String uid, String fallback) =>
    friendlyMemberName(ref.watch(groupMemberNameProvider(uid)).value) ??
    fallback;

/// Member avatars in a row, overlapping slightly, each with a white ring.
class AvatarRow extends ConsumerWidget {
  const AvatarRow({
    super.key,
    required this.memberIds,
    this.size = 30,
    this.max = 5,
  });

  final List<String> memberIds;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ring = Theme.of(context).colorScheme.surface;
    final shown = memberIds.take(max).toList();
    const overlap = 6.0;
    return SizedBox(
      height: size,
      width: shown.isEmpty ? 0 : size + (shown.length - 1) * (size - overlap),
      child: Stack(
        children: [
          for (final (i, id) in shown.indexed)
            Positioned(
              left: i * (size - overlap),
              child: MemberAvatar(
                id: id,
                name: memberName(ref, id, ''),
                size: size,
                borderColor: ring,
              ),
            ),
        ],
      ),
    );
  }
}

/// Grabber at the top of modal sheets.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        width: 36,
        height: 5,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

/// Shows a snackbar with [message].
void showTripSnack(BuildContext context, String message, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? scheme.error : null,
  ));
}

/// Dates of a trip in the app's locale, null without dates.
String? tripDatesLabel(BuildContext context, GroupModel group) {
  if (group.tripStart == null) return null;
  return formatTripDates(group.tripStart!, group.tripEnd,
      Localizations.localeOf(context).toLanguageTag());
}

/// Loading and error states of the full-screen trip pages: [child] with a
/// back button on top, so nobody gets stuck on a spinner without a way out.
class WithBackButton extends StatelessWidget {
  const WithBackButton({
    super.key,
    required this.child,
    required this.fallbackRoute,
  });

  final Widget child;

  /// Where back goes when there is nothing to pop (deep link).
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 16,
          child: GlassButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: context.l10n.back,
            opacity: 1,
            onTap: () =>
                context.canPop() ? context.pop() : context.go(fallbackRoute),
          ),
        ),
      ],
    );
  }
}
