/// A simple, approximate syllable splitter for the Learn flashcard's visual
/// "syllable separation" - decorative only, not used for pronunciation
/// scoring (that is handled server-side by the real G2P/Whisper pipeline).
///
/// Splits on vowel-group boundaries: a single consonant between two vowel
/// groups attaches to the following syllable, two or more are split down
/// the middle. This is a common English heuristic and will not be exactly
/// right for every word, which is acceptable for a visual aid.
library;

List<String> splitSyllables(String word) {
  final trimmed = word.trim();
  if (trimmed.isEmpty) return const [];

  final lower = trimmed.toLowerCase();
  const vowels = 'aeiouy';
  bool isVowel(int i) => vowels.contains(lower[i]);

  final nucleusStarts = <int>[
    for (var i = 0; i < lower.length; i++)
      if (isVowel(i) && (i == 0 || !isVowel(i - 1))) i,
  ];

  if (nucleusStarts.length <= 1) return [trimmed];

  final boundaries = <int>[];
  for (var n = 0; n < nucleusStarts.length - 1; n++) {
    var nucleusEnd = nucleusStarts[n];
    while (nucleusEnd < lower.length && isVowel(nucleusEnd)) {
      nucleusEnd++;
    }
    final consonantCount = nucleusStarts[n + 1] - nucleusEnd;
    boundaries.add(
      consonantCount <= 1
          ? nucleusEnd
          : nucleusEnd + (consonantCount / 2).ceil(),
    );
  }

  final syllables = <String>[];
  var start = 0;
  for (final boundary in boundaries) {
    syllables.add(trimmed.substring(start, boundary));
    start = boundary;
  }
  syllables.add(trimmed.substring(start));
  return syllables;
}
