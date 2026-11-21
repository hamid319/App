import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/utils/passport_stamps.dart';
import '../../../common/widgets/ticket.dart';
import '../../../common/widgets/visited_map.dart';
import '../../../common/widgets/wallet_app_bar.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/services/maps_availability.dart';
import '../../../l10n/l10n.dart';
import '../logic/passport_controller.dart';

final _mapsConfiguredProvider =
    FutureProvider<bool>((ref) => MapsAvailability().isConfigured());

/// The world with every city the user has travelled to lit up in orange
/// (the same cities as the stamp book). Only map tiles come from Mapbox.
class TravelMapScreen extends ConsumerWidget {
  const TravelMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final configured = ref.watch(_mapsConfiguredProvider);
    final stamps = ref.watch(passportStampsProvider);
    final cities = [
      for (final s in stamps.value ?? const <PassportStamp>[])
        if (s.lat != 0 || s.lng != 0) (s.lat, s.lng),
    ];

    return Scaffold(
      appBar: WalletAppBar(
        color: BrandColors.orange,
        onColor: BrandColors.navy,
        icon: Icons.map_rounded,
        title: l10n.profileMapTab,
      ),
      body: switch (configured) {
        AsyncData(value: false) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.space24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const IconBadge(icon: Icons.map_outlined, tone: ChipTone.sky),
                  const SizedBox(height: AppSizes.space24),
                  Text(l10n.mapsNotConfigured, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        // The world shows right away; the cities light up once known.
        AsyncData() => Stack(fit: StackFit.expand, children: [
            VisitedMap(cities: cities),
            if (stamps.hasValue && cities.isEmpty)
              Positioned(
                left: 24,
                right: 24,
                bottom: 72,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Text(
                        l10n.travelMapEmpty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
