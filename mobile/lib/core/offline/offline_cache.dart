import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/locale_provider.dart';

/// A small write-through JSON cache for the data that matters most when a
/// lesson is opened with no connection: which lessons exist, and what the
/// last-known progress/report looked like. Illustrations are cached
/// separately, by `cached_network_image`, to disk at the HTTP layer.
///
/// Deliberately not a full offline database (no sqlite, no sync log) - the
/// backend is the single source of truth and this only ever holds "the last
/// good answer", overwritten every time a live fetch succeeds and read only
/// when one fails.
class OfflineCache {
  OfflineCache(this._preferences);

  final Future<SharedPreferences> _preferences;

  static const _lessonsPrefix = 'offline_cache.lessons.';
  static const _progressPrefix = 'offline_cache.progress.';

  Future<void> saveLessons(String languageCode, List<dynamic> rawJson) async {
    final prefs = await _preferences;
    await prefs.setString('$_lessonsPrefix$languageCode', jsonEncode(rawJson));
  }

  /// Null when nothing has ever been cached for this language.
  Future<List<dynamic>?> readLessons(String languageCode) async {
    final prefs = await _preferences;
    final raw = prefs.getString('$_lessonsPrefix$languageCode');
    if (raw == null) return null;
    return jsonDecode(raw) as List<dynamic>;
  }

  Future<void> saveProgressReport(
    int profileId,
    Map<String, dynamic> rawJson,
  ) async {
    final prefs = await _preferences;
    await prefs.setString(
      '$_progressPrefix$profileId',
      jsonEncode(rawJson),
    );
  }

  Future<Map<String, dynamic>?> readProgressReport(int profileId) async {
    final prefs = await _preferences;
    final raw = prefs.getString('$_progressPrefix$profileId');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

final offlineCacheProvider = Provider<OfflineCache>((ref) {
  return OfflineCache(ref.watch(sharedPreferencesProvider));
});
