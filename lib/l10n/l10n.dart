import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// Short access to the translated strings: `context.l10n.cancel`.
/// Texts live in `app_en.arb` (template) and `app_de.arb`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
