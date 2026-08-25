import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/offline/sync_coordinator.dart';
import 'theme/theme.dart';
import 'l10n/l10n.dart';
import 'providers/locale_provider.dart';
import 'routes/app_router.dart';

void main() {
  runApp(const ProviderScope(child: HearAndSpeakApp()));
}

class HearAndSpeakApp extends ConsumerWidget {
  const HearAndSpeakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the offline sync queue's connectivity listener alive for the
    // whole app lifetime - see SyncCoordinator's docstring.
    activateSyncCoordinator(ref);

    final router = ref.watch(routerProvider);

    // Null means "follow the device locale", which is the right default for a
    // Malaysian device already set to Malay.
    final locale = ref.watch(localeControllerProvider);

    return MaterialApp.router(
      title: 'Hear & Speak Together',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,

      locale: locale,
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
