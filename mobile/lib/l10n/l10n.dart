import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// Shorthand so screens read `context.l10n.authSignIn` rather than
/// `AppL10n.of(context).authSignIn`.
extension AppLocalizationsX on BuildContext {
  AppL10n get l10n => AppL10n.of(this);
}
