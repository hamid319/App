import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/home_city_controller.dart';
import '../../../app/theme.dart';
import '../../../common/widgets/city_picker.dart';
import '../../../common/widgets/ticket.dart';
import '../../../core/constants/popular_cities.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/constants/typography.dart';
import '../../../core/errors/user_message.dart';
import '../../../l10n/l10n.dart';
import '../data/city_tip_repository.dart';
import '../logic/city_tip_controller.dart';

/// "Know a real hidden gem in Berlin?" on the home screen. Asks for the
/// home city first when it is not set. Hidden while paused (see
/// [cityTipBannerProvider]).
class CityTipBanner extends ConsumerWidget {
  const CityTipBanner({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    var city = ref.read(homeCityProvider);
    if (city == null) {
      PopularCity? chosen;
      await showCityPicker(
        context,
        offerCurrentLocation: false,
        title: context.l10n.homeCityPickerTitle,
        onSelected: (c) => chosen = c,
      );
      if (chosen == null) return;
      await ref.read(homeCityProvider.notifier).setCity(chosen);
      city = chosen;
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _TipSheet(city: city!),
    );
  }

  static const double _stub = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(cityTipBannerProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final city = ref.watch(homeCityProvider);
    final lang = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.screenEdge, 0, AppSizes.screenEdge, AppSizes.groupGap),
      child: Ticket(
        color: context.swipeColors.peach,
        notchFromBottom: _stub,
        onTap: () => _start(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.space24,
                  AppSizes.space16, AppSizes.space8, AppSizes.space16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: AppSizes.space8),
                          child: Stamp(
                            text: l10n.cityTipStamp,
                            color: context.swipeColors.gold,
                            size: 20,
                            angle: -0.06,
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: AppSizes.space12),
                        Text(
                          city == null
                              ? l10n.cityTipBannerTitleNoCity
                              : l10n.cityTipBannerTitle(city.nameFor(lang)),
                          style: AppTypography.display(
                              size: 24, color: scheme.onSurface, height: 1.1),
                        ),
                        const SizedBox(height: AppSizes.space8),
                        Text(
                          l10n.cityTipBannerBody,
                          style: text.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.cityTipBannerNotNow,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded,
                        color: scheme.onSurfaceVariant),
                    onPressed: () =>
                        ref.read(cityTipBannerProvider.notifier).dismiss(),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: _stub,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSizes.space24),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates_rounded,
                        size: 20, color: scheme.onSurface),
                    const SizedBox(width: AppSizes.space8),
                    Expanded(
                      child: Text(l10n.cityTipBannerAction,
                          style: text.labelLarge),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: scheme.onSurface),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipSheet extends ConsumerStatefulWidget {
  const _TipSheet({required this.city});

  final PopularCity city;

  @override
  ConsumerState<_TipSheet> createState() => _TipSheetState();
}

class _TipSheetState extends ConsumerState<_TipSheet> {
  final _place = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _place.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(cityTipBannerProvider.notifier).submit(
            cityId: widget.city.id,
            place: _place.text,
            note: _note.text,
            language: lang,
          );
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.cityTipThanks)));
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(
        content:
            Text(userMessage(e, fallback: l10n.cityTipSaveError, l10n: l10n)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.screenEdge,
        AppSizes.space16,
        AppSizes.screenEdge,
        MediaQuery.viewInsetsOf(context).bottom + AppSizes.space24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.cityTipSheetTitle(widget.city.nameFor(lang)),
              style: text.titleLarge),
          const SizedBox(height: AppSizes.space4),
          Text(l10n.cityTipSheetHint,
              style: text.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSizes.space16),
          TextField(
            controller: _place,
            autofocus: true,
            maxLength: CityTipRepository.maxPlaceLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.cityTipPlaceLabel),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _note,
            maxLength: CityTipRepository.maxNoteLength,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.cityTipNoteLabel),
          ),
          const SizedBox(height: AppSizes.space8),
          FilledButton(
            onPressed: _saving || _place.text.trim().isEmpty ? null : _submit,
            child: Text(l10n.cityTipSubmit),
          ),
        ],
      ),
    );
  }
}
