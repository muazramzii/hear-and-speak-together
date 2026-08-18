import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The interface language of the app.
///
/// Deliberately separate from a profile's *practice* language. A child can
/// read Malay menus while practising English pronunciation, and conflating
/// the two would silently change what they are being taught whenever they
/// changed the menu language.
class LocaleController extends StateNotifier<Locale?> {
  LocaleController(this._preferences) : super(null) {
    _restore();
  }

  final Future<SharedPreferences> _preferences;

  static const _key = 'interface_locale';
  static const supportedLocales = [Locale('en'), Locale('ms')];

  Future<void> _restore() async {
    final prefs = await _preferences;
    final code = prefs.getString(_key);
    if (code != null && supportedLocales.any((l) => l.languageCode == code)) {
      state = Locale(code);
    }
    // Null means "follow the device", which is the right default: a Malaysian
    // device set to Malay should open in Malay without being asked.
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = await _preferences;
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
  }
}

final sharedPreferencesProvider = Provider<Future<SharedPreferences>>((ref) {
  return SharedPreferences.getInstance();
});

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale?>((ref) {
      return LocaleController(ref.watch(sharedPreferencesProvider));
    });
