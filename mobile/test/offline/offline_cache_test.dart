import 'package:flutter_test/flutter_test.dart';
import 'package:hear_speak_together/core/offline/offline_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('OfflineCache lessons', () {
    test('a language with nothing cached reads as null', () async {
      final cache = OfflineCache(SharedPreferences.getInstance());

      expect(await cache.readLessons('en'), isNull);
    });

    test('round-trips a lesson list', () async {
      final cache = OfflineCache(SharedPreferences.getInstance());
      final lessons = [
        {'id': 1, 'title': 'Animals', 'word_count': 6},
      ];

      await cache.saveLessons('en', lessons);
      final result = await cache.readLessons('en');

      expect(result, hasLength(1));
      expect((result!.first as Map)['title'], 'Animals');
    });

    test('languages are cached independently', () async {
      final cache = OfflineCache(SharedPreferences.getInstance());

      await cache.saveLessons('en', [
        {'id': 1, 'title': 'Animals'},
      ]);
      await cache.saveLessons('ms', [
        {'id': 2, 'title': 'Haiwan'},
      ]);

      final en = await cache.readLessons('en');
      final ms = await cache.readLessons('ms');

      expect((en!.first as Map)['title'], 'Animals');
      expect((ms!.first as Map)['title'], 'Haiwan');
    });
  });

  group('OfflineCache progress reports', () {
    test('a profile with nothing cached reads as null', () async {
      final cache = OfflineCache(SharedPreferences.getInstance());

      expect(await cache.readProgressReport(1), isNull);
    });

    test('round-trips a progress report and overwrites on re-save', () async {
      final cache = OfflineCache(SharedPreferences.getInstance());

      await cache.saveProgressReport(1, {
        'summary': {'average_score': 70},
      });
      await cache.saveProgressReport(1, {
        'summary': {'average_score': 90},
      });

      final result = await cache.readProgressReport(1);

      expect((result!['summary'] as Map)['average_score'], 90);
    });
  });
}
