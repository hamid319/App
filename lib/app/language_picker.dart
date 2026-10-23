import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/widgets/ticket.dart';
import '../core/constants/sizes.dart';
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
    builder: (sheetContext) {
      final selected = ref.read(localeControllerProvider)?.languageCode;
      final l10n = sheetContext.l10n;
      Widget option(String? code) => ListTile(
            title: Text(languageName(l10n, code)),
            trailing: selected == code
                ? Icon(Icons.check_rounded,
                    color: Theme.of(sheetContext).colorScheme.onSurface)
                : null,
            onTap: () {
              ref.read(localeControllerProvider.notifier).setLanguage(code);
              Navigator.pop(sheetContext);
            },
          );
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenEdge,
                0,
                AppSizes.screenEdge,
                AppSizes.space12,
              ),
              child: Text(
                l10n.languageTitle,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            _OptionsTicket(options: [
              option(null),
              for (final code in supportedLanguageCodes) option(code),
            ]),
          ],
        ),
      );
    },
  );
}

/// The sheet's options as rows of one ticket.
class _OptionsTicket extends StatelessWidget {
  const _OptionsTicket({required this.options});

  final List<Widget> options;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenEdge,
        0,
        AppSizes.screenEdge,
        AppSizes.space16,
      ),
      child: Ticket(
        child: Column(
          children: [
            for (final (i, option) in options.indexed) ...[
              if (i > 0) const Divider(height: 1),
              option,
            ],
          ],
        ),
      ),
    );
  }
}
