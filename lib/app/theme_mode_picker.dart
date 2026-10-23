import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/widgets/ticket.dart';
import '../core/constants/sizes.dart';
import '../l10n/l10n.dart';
import 'theme_mode_controller.dart';

String themeModeName(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
      ThemeMode.light => l10n.appearanceLight,
      ThemeMode.dark => l10n.appearanceDark,
      ThemeMode.system => l10n.appearanceSystem,
    };

/// Bottom sheet with "System default", "Light" and "Dark".
Future<void> showThemeModePicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    // Above the shell's bottom navigation bar, which would cover the options.
    useRootNavigator: true,
    builder: (sheetContext) {
      final selected = ref.read(themeModeControllerProvider);
      final l10n = sheetContext.l10n;
      Widget option(ThemeMode mode, IconData icon) => ListTile(
            leading: Icon(icon),
            title: Text(themeModeName(l10n, mode)),
            trailing: selected == mode
                ? Icon(Icons.check_rounded,
                    color: Theme.of(sheetContext).colorScheme.onSurface)
                : null,
            onTap: () {
              ref.read(themeModeControllerProvider.notifier).setThemeMode(mode);
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
                l10n.appearanceTitle,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            _OptionsTicket(options: [
              option(ThemeMode.system, Icons.brightness_auto_outlined),
              option(ThemeMode.light, Icons.light_mode_outlined),
              option(ThemeMode.dark, Icons.dark_mode_outlined),
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
