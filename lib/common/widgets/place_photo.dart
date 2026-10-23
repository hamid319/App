import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/sizes.dart';
import '../utils/place_photo_url_builder.dart';
import '../models/place_model.dart';
import 'skeleton.dart';
import 'ticket.dart';

/// Hero tag shared by the swipe card photo and the place detail header, so
/// the photo grows from the card into the detail page.
String placePhotoHeroTag(String placeId) => 'place-photo-$placeId';

/// A place's first photo filling its box, with a warm gradient while it
/// loads or when there is no photo. Venues without a photo (most of them,
/// OpenStreetMap has none) get a pastel illustration with their type icon.
class PlacePhoto extends StatelessWidget {
  const PlacePhoto({super.key, required this.place});

  final PlaceModel place;

  @override
  Widget build(BuildContext context) {
    final urls = resolvePlacePhotoUrls(place);
    final venueIcon = venueTypeIcon(place.types);
    final Widget fallback = place.isVenue || venueIcon != null
        ? _VenueIllustration(
            icon: venueIcon ?? Icons.storefront_rounded,
            tone: _venueTone(place.types))
        : const _PhotoFallback();
    if (urls.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: urls.first,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) => const SkeletonImage(),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.swipeColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.peach, scheme.primaryContainer, colors.sky],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.landscape_rounded,
          size: 64,
          color: scheme.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

/// Icon for a venue's type, or null when [types] holds no venue type.
IconData? venueTypeIcon(List<String> types) {
  for (final type in types) {
    final icon = switch (type) {
      'restaurant' => Icons.restaurant,
      'cafe' => Icons.local_cafe,
      'bar' => Icons.local_bar,
      'pub' => Icons.sports_bar,
      'biergarten' => Icons.deck,
      'night_club' => Icons.nightlife,
      _ => null,
    };
    if (icon != null) return icon;
  }
  return null;
}

enum _Tone { peach, gold, sky, mint }

_Tone _venueTone(List<String> types) {
  for (final type in types) {
    switch (type) {
      case 'restaurant':
        return _Tone.peach;
      case 'cafe':
        return _Tone.gold;
      case 'bar' || 'night_club':
        return _Tone.sky;
      case 'pub' || 'biergarten':
        return _Tone.mint;
    }
  }
  return _Tone.peach;
}

/// Pastel paper with a dotted print pattern and the type icon on an
/// ink-rimmed disc: a deliberate illustration rather than a missing photo.
class _VenueIllustration extends StatelessWidget {
  const _VenueIllustration({required this.icon, required this.tone});

  final IconData icon;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.swipeColors;
    final scheme = Theme.of(context).colorScheme;
    final fill = switch (tone) {
      _Tone.peach => c.peach,
      _Tone.gold =>
        Color.alphaBlend(c.gold.withValues(alpha: 0.35), scheme.surface),
      _Tone.sky => c.sky,
      _Tone.mint => c.mint,
    };
    return ColoredBox(
      color: fill,
      child: CustomPaint(
        painter: _DotsPainter(scheme.onSurface.withValues(alpha: 0.09)),
        child: LayoutBuilder(builder: (context, box) {
          final side = box.biggest.shortestSide;
          final disc = (side.isFinite ? side * 0.42 : 72.0).clamp(32.0, 104.0);
          return Center(
            child: Transform.rotate(
              angle: -0.06,
              child: Container(
                width: disc,
                height: disc,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surface,
                  border: Border.all(color: c.edge, width: AppSizes.edge),
                  boxShadow: printShadow(c.edge),
                ),
                child: Icon(icon, size: disc * 0.5, color: scheme.onSurface),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const step = 14.0;
    final paint = Paint()..color = color;
    var row = 0;
    for (var y = step / 2; y < size.height; y += step, row++) {
      final shift = row.isOdd ? step / 2 : 0.0;
      for (var x = step / 2 + shift; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

/// Tag chip that stays readable on any photo: dark glass with a light rim.
class PhotoChip extends StatelessWidget {
  const PhotoChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: PhotoColors.chip,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PhotoColors.chipBorder),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
