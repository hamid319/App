import 'package:flutter/material.dart';

import '../../../common/widgets/ticket.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/services/maps_launcher.dart';
import '../../../l10n/l10n.dart';

/// Lets the user pick Apple Maps or Google Maps for the route (iOS only;
/// Android always uses Google Maps). Returns null when dismissed.
Future<MapsApp?> showMapsAppSheet(BuildContext context) {
  final l10n = context.l10n;
  return showModalBottomSheet<MapsApp>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final text = Theme.of(sheetContext).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenEdge,
            0,
            AppSizes.screenEdge,
            AppSizes.space16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.mapsChooseTitle, style: text.titleLarge),
              const SizedBox(height: AppSizes.space12),
              _MapsOption(
                icon: Icons.map_outlined,
                label: l10n.appleMaps,
                onTap: () => Navigator.of(sheetContext).pop(MapsApp.apple),
              ),
              const SizedBox(height: AppSizes.space8),
              _MapsOption(
                icon: Icons.directions_outlined,
                label: l10n.googleMaps,
                onTap: () => Navigator.of(sheetContext).pop(MapsApp.google),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _MapsOption extends StatelessWidget {
  const _MapsOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Ticket(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSizes.space16),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSurface),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
