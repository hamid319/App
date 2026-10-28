import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../common/models/journal_entry.dart';
import '../../../common/widgets/wordmark.dart';
import '../../../core/constants/colors.dart';

/// Size of the shared recap image (Instagram portrait).
const recapCardSize = Size(1080, 1350);

/// The recap as a picture to share: wordmark, up to four photos, trip
/// name, dates and a row of stats. Always light, whatever the app theme.
class RecapShareCard extends StatelessWidget {
  const RecapShareCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.photos,
    required this.stats,
  });

  final String title;
  final String subtitle;
  final List<JournalPhoto> photos;

  /// Value and label, e.g. (5, 'days').
  final List<(int, String)> stats;

  static const _grey = Color(0xFF6E6E73);

  @override
  Widget build(BuildContext context) {
    Widget photo(JournalPhoto p) => Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            // A plain Image: CachedNetworkImage fades in, which a capture
            // right after precaching would catch half way.
            child: Image(
              image: CachedNetworkImageProvider(p.url),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        );
    Widget row(List<JournalPhoto> ps) => Expanded(
          child: Row(
            children: [
              for (final (i, p) in ps.indexed) ...[
                if (i > 0) const SizedBox(width: 16),
                photo(p),
              ],
            ],
          ),
        );

    return Theme(
      data: AppTheme.light,
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(72),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Wordmark(size: 48),
              const SizedBox(height: 40),
              if (photos.isEmpty)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: BrandColors.sky,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Center(
                      child: Icon(Icons.luggage_rounded,
                          size: 160, color: BrandColors.navy),
                    ),
                  ),
                )
              else if (photos.length <= 2)
                row(photos)
              else ...[
                row(photos.take(2).toList()),
                const SizedBox(height: 16),
                row(photos.skip(2).take(2).toList()),
              ],
              const SizedBox(height: 44),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 72,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: BrandColors.navy,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 34, color: _grey)),
              ],
              const SizedBox(height: 40),
              Row(
                children: [
                  for (final (value, label) in stats)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$value',
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w800,
                                color: BrandColors.coral,
                              )),
                          Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontSize: 30, color: _grey)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
