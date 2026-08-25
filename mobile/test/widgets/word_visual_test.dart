import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear_speak_together/models/content.dart';
import 'package:hear_speak_together/widgets/word_visual.dart';

Word _word({String image = '', String emoji = ''}) => Word(
  id: 1,
  text: 'kucing',
  meaning: '',
  exampleSentence: '',
  imageUrl: image,
  emoji: emoji,
  audioUrl: '',
);

Widget _harness(Word word) =>
    MaterialApp(home: Scaffold(body: WordVisual(word: word)));

void main() {
  group('fallback order', () {
    testWidgets('shows the emoji when there is no illustration', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_word(emoji: '🐱')));

      expect(find.text('🐱'), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsNothing);
    });

    testWidgets('falls back to a generic icon with neither', (tester) async {
      await tester.pumpWidget(_harness(_word()));

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('prefers a real illustration over the emoji', (tester) async {
      await tester.pumpWidget(
        _harness(_word(image: 'https://example.com/cat.png', emoji: '🐱')),
      );

      // The cached illustration widget is present (and takes priority over
      // the emoji fallback) even before the network request resolves -
      // CachedNetworkImage renders its own placeholder while loading rather
      // than falling through to the emoji.
      expect(find.byType(CachedNetworkImage), findsOneWidget);
      expect(find.text('🐱'), findsNothing);
    });
  });

  group('distinguishability', () {
    testWidgets('four options render four different visuals', (tester) async {
      // This is the whole point of the emoji field. A Listen round hides the
      // word, so if every tile fell back to the same placeholder the question
      // could only be guessed.
      const emojis = ['🐱', '🐶', '🐘', '🦁'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (final emoji in emojis)
                  WordVisual(word: _word(emoji: emoji)),
              ],
            ),
          ),
        ),
      );

      for (final emoji in emojis) {
        expect(find.text(emoji), findsOneWidget);
      }
    });
  });

  group('accessibility', () {
    testWidgets('the emoji is hidden from screen readers', (tester) async {
      // The surrounding tile already announces the word; hearing "cat face"
      // over it would be noise.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(_word(emoji: '🐱')));

      // Scoped to the widget under test - Material internals add their own
      // ExcludeSemantics nodes.
      expect(
        find.descendant(
          of: find.byType(WordVisual),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );

      // And the emoji really is absent from the semantics tree.
      expect(
        find.bySemanticsLabel('🐱'),
        findsNothing,
        reason: 'a screen reader should not read the emoji out',
      );

      handle.dispose();
    });
  });

  group('Word.hasVisual', () {
    test('is true with an emoji alone', () {
      expect(_word(emoji: '🐱').hasVisual, isTrue);
    });

    test('is true with an image alone', () {
      expect(_word(image: 'https://example.com/a.png').hasVisual, isTrue);
    });

    test('is false with neither', () {
      expect(_word().hasVisual, isFalse);
    });
  });

  group('parsing', () {
    test('reads the emoji from the API payload', () {
      final word = Word.fromJson(const {
        'id': 3,
        'text': 'gajah',
        'emoji': '🐘',
      });

      expect(word.emoji, '🐘');
      expect(word.hasVisual, isTrue);
    });

    test('a payload without an emoji still parses', () {
      final word = Word.fromJson(const {'id': 3, 'text': 'gajah'});

      expect(word.emoji, '');
      expect(word.hasVisual, isFalse);
    });
  });
}
