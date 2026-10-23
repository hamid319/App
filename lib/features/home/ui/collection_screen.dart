import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/widgets/skeleton.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../logic/home_feed_controller.dart';
import '../widgets/place_ticket_tile.dart';
import 'home_screen.dart';

const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: AppSizes.space16,
  crossAxisSpacing: AppSizes.space12,
  childAspectRatio: 0.7,
);

/// All places of one home row ("All"), as a two-column ticket grid like
/// the favorites. [theme] is the route slug, see [HomeCollection].
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key, required this.theme});

  final String theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final collection = HomeCollection.fromSlug(theme);
    final feed = ref.watch(homeFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          collection == null ? '' : homeCollectionTitle(l10n, collection),
        ),
      ),
      body: feed.when(
        loading: () => Skeleton(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSizes.screenEdge),
            gridDelegate: _gridDelegate,
            itemCount: 6,
            itemBuilder: (_, __) => const SkeletonBox(
              width: double.infinity,
              radius: AppSizes.radiusTicket,
            ),
          ),
        ),
        error: (e, _) => _Message(
          icon: Icons.cloud_off_rounded,
          text: userMessage(e, fallback: l10n.errorLoadPlaces, l10n: l10n),
        ),
        data: (feed) {
          final places =
              collection == null ? const [] : feed.places(collection);
          if (places.isEmpty) {
            return _Message(
              icon: Icons.travel_explore,
              text: l10n.collectionEmpty,
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.screenEdge,
              AppSizes.space8,
              AppSizes.screenEdge,
              AppSizes.space24,
            ),
            gridDelegate: _gridDelegate,
            itemCount: places.length,
            itemBuilder: (context, i) => PlaceTicketTile(
              place: places[i],
              subtitle: placeCategoryLabel(context, places[i]),
              tone: placeTicketTones[i % placeTicketTones.length],
            ),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(icon: icon, tone: ChipTone.sky),
            const SizedBox(height: AppSizes.space24),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
