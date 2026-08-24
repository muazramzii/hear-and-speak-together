import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/locale_provider.dart';

/// Parent Mode's own accessibility preferences - dark mode and a large-text
/// scale - kept separate from the child app, which has no such settings.
class ParentPreferences {
  const ParentPreferences({required this.themeMode, required this.textScale});

  final ThemeMode themeMode;

  /// A multiplier on the base text size, not a fixed size - so it composes
  /// with whatever the device's own accessibility text setting already is.
  final double textScale;

  static const defaults = ParentPreferences(
    themeMode: ThemeMode.system,
    textScale: 1.0,
  );

  ParentPreferences copyWith({ThemeMode? themeMode, double? textScale}) {
    return ParentPreferences(
      themeMode: themeMode ?? this.themeMode,
      textScale: textScale ?? this.textScale,
    );
  }
}

/// Persisted the same way the interface-language setting is (see
/// `LocaleController`) - `SharedPreferences` via `sharedPreferencesProvider`.
class ParentPreferencesController extends StateNotifier<ParentPreferences> {
  ParentPreferencesController(this._preferences)
    : super(ParentPreferences.defaults) {
    _restore();
  }

  final Future<SharedPreferences> _preferences;

  static const _themeModeKey = 'parent_theme_mode';
  static const _textScaleKey = 'parent_text_scale';

  Future<void> _restore() async {
    final prefs = await _preferences;
    final storedMode = prefs.getString(_themeModeKey);
    final storedScale = prefs.getDouble(_textScaleKey);

    state = ParentPreferences(
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == storedMode,
        orElse: () => ThemeMode.system,
      ),
      textScale: storedScale ?? 1.0,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await _preferences;
    await prefs.setString(_themeModeKey, mode.name);
  }

  Future<void> setTextScale(double scale) async {
    state = state.copyWith(textScale: scale);
    final prefs = await _preferences;
    await prefs.setDouble(_textScaleKey, scale);
  }
}

final parentPreferencesProvider =
    StateNotifierProvider<ParentPreferencesController, ParentPreferences>((
      ref,
    ) {
      return ParentPreferencesController(ref.watch(sharedPreferencesProvider));
    });
