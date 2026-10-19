import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/l10n.dart';
import 'locale_controller.dart';

/// Language names are shown in their own language ("Deutsch", "English"), so
/// people can find theirs even when the app is in a language they can't read.
String languageName(AppLocalizations l10n, String? code) => switch (code) {
      'en' => l10n.languageEnglish,
      'de' => l10n.languageGerman,
      _ => l10n.languageSystem,
    };

/// Bottom sheet with "System default", "English" and "Deutsch".
Future<void> showLanguagePicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    // Above the shell's bottom navigation bar, which would cover the options.
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final selected = ref.read(localeControllerProvider)?.languageCode;
      final l10n = sheetContext.l10n;
      Widget option(String? code) => ListTile(
            title: Text(languageName(l10n, code)),
            trailing: selected == code
                ? Icon(Icons.check,
                    color: Theme.of(sheetContext).colorScheme.primary)
                : null,
            onTap: () {
              ref.read(localeControllerProvider.notifier).setLanguage(code);
              Navigator.pop(sheetContext);
            },
          );
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.languageTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            option(null),
            for (final code in supportedLanguageCodes) option(code),
          ],
        ),
      );
    },
  );
}

/// Compact DE | EN switch for the onboarding screen. Shows the language the
/// app is currently displayed in, which may come from the device.
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = Localizations.localeOf(context).languageCode;
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: [
        for (final code in supportedLanguageCodes)
          ButtonSegment(
            value: code,
            label: Text(code.toUpperCase()),
            tooltip: languageName(context.l10n, code),
          ),
      ],
      selected: {current},
      onSelectionChanged: (selection) => ref
          .read(localeControllerProvider.notifier)
          .setLanguage(selection.first),
    );
  }
}
