import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_speak_together/l10n/l10n.dart';

Widget _harness(Locale locale, Widget child) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppL10n.supportedLocales,
    localizationsDelegates: const [
      AppL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  group('translation coverage', () {
    late Map<String, dynamic> english;
    late Map<String, dynamic> malay;

    setUpAll(() {
      english = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync());
      malay = jsonDecode(File('lib/l10n/app_ms.arb').readAsStringSync());
    });

    bool isMessage(String key) => !key.startsWith('@');

    test('every English string has a Malay translation', () {
      final missing =
          english.keys
              .where(isMessage)
              .where((key) => !malay.containsKey(key))
              .toList();

      expect(
        missing,
        isEmpty,
        reason: 'Untranslated keys would fall back to English mid-screen.',
      );
    });

    test('Malay has no orphan keys', () {
      final orphans =
          malay.keys
              .where(isMessage)
              .where((key) => !english.containsKey(key))
              .toList();

      expect(orphans, isEmpty);
    });

    test('no Malay value is left as the English text', () {
      // A handful of strings are intentionally identical - the app name and
      // the mode names are kept in English in the design.
      // The design keeps the four mode names in English in both languages,
      // so these are deliberately identical rather than untranslated.
      const intentionallyShared = {
        'appTitle',
        'modeLearn',
        'modeListen',
        'modeSpeak',
        'modeQuiz',
        'navProgress',
        'learnTitle',
        'listenTitle',
        'speakTitle',
        'quizTitle',
        // "min" as a minutes abbreviation reads the same in both languages;
        // only the surrounding placeholders differ, so there is no distinct
        // Malay wording to write here.
        'lessonIntroMinutesRange',
      };

      final untranslated =
          english.keys
              .where(isMessage)
              .where((key) => !intentionallyShared.contains(key))
              .where((key) => english[key] == malay[key])
              .toList();

      expect(untranslated, isEmpty);
    });
  });

  group('runtime lookup', () {
    testWidgets('resolves English strings', (tester) async {
      late AppL10n l10n;
      await tester.pumpWidget(
        _harness(
          const Locale('en'),
          Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.authSignIn, 'Sign In');
      expect(l10n.navHome, 'Home');
    });

    testWidgets('resolves Malay strings', (tester) async {
      late AppL10n l10n;
      await tester.pumpWidget(
        _harness(
          const Locale('ms'),
          Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.authSignIn, 'Log Masuk');
      expect(l10n.authPassword, 'Kata Laluan');
      expect(l10n.navHome, 'Utama');
      expect(l10n.navRewards, 'Ganjaran');
      expect(l10n.navSettings, 'Tetapan');
      expect(l10n.profileChooseTitle, 'Pilih Profil');
    });

    testWidgets('interpolates placeholders in both languages', (tester) async {
      late AppL10n english;
      late AppL10n malay;

      await tester.pumpWidget(
        _harness(
          const Locale('en'),
          Builder(
            builder: (context) {
              english = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        _harness(
          const Locale('ms'),
          Builder(
            builder: (context) {
              malay = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(english.homeGreeting('Ali'), 'Hi, Ali!');
      expect(malay.homeGreeting('Ali'), 'Hai, Ali!');
      expect(english.profileLevel(3), 'Level 3');
      expect(malay.profileLevel(3), 'Tahap 3');
    });
  });
}
