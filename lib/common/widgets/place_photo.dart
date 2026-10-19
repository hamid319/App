import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../utils/place_photo_url_builder.dart';
import '../models/place_model.dart';
import 'skeleton.dart';

/// Hero tag shared by the swipe card photo and the place detail header, so
/// the photo grows from the card into the detail page.
String placePhotoHeroTag(String placeId) => 'place-photo-$placeId';

/// A place's first photo filling its box, with a warm gradient while it
/// loads or when there is no photo.
class PlacePhoto extends StatelessWidget {
  const PlacePhoto({super.key, required this.place});

  final PlaceModel place;

  @override
  Widget build(BuildContext context) {
    final urls = resolvePlacePhotoUrls(place);
    const fallback = _PhotoFallback();
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
    final primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(primary, Colors.white, 0.35)!,
            primary,
            const Color(0xFF5B4E9E),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.landscape_rounded, size: 64, color: Colors.white70),
      ),
    );
  }
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

