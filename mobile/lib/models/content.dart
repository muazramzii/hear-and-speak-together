/// What Azure AI Speech can actually measure for a given locale.
///
/// These come from the backend rather than being hardcoded, because Azure's
/// feature set is not identical across locales - prosody, for instance, is
/// documented as en-US only. The UI must render only the metrics listed here
/// so a score that was never measured is never displayed.
class LanguageCapabilities {
  const LanguageCapabilities({
    required this.pronunciationAssessment,
    required this.prosody,
    required this.phonemeNames,
    required this.syllableScores,
    required this.availableMetrics,
  });

  final bool pronunciationAssessment;
  final bool prosody;
  final bool phonemeNames;
  final bool syllableScores;
  final List<String> availableMetrics;

  bool supports(String metric) => availableMetrics.contains(metric);

  factory LanguageCapabilities.fromJson(Map<String, dynamic> json) {
    return LanguageCapabilities(
      pronunciationAssessment: json['pronunciation_assessment'] as bool? ?? false,
      prosody: json['prosody'] as bool? ?? false,
      phonemeNames: json['phoneme_names'] as bool? ?? false,
      syllableScores: json['syllable_scores'] as bool? ?? false,
      availableMetrics:
          (json['available_metrics'] as List?)?.cast<String>() ?? const [],
    );
  }
}

class LanguageInfo {
  const LanguageInfo({
    required this.id,
    required this.code,
    required this.name,
    required this.locale,
    required this.ttsVoice,
    required this.capabilities,
  });

  final int id;
  final String code;
  final String name;
  final String locale;
  final String ttsVoice;
  final LanguageCapabilities capabilities;

  factory LanguageInfo.fromJson(Map<String, dynamic> json) {
    return LanguageInfo(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String? ?? '',
      locale: json['locale'] as String? ?? '',
      ttsVoice: json['tts_voice'] as String? ?? '',
      capabilities: LanguageCapabilities.fromJson(
        (json['capabilities'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

class Category {
  const Category({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.icon,
    required this.imageUrl,
    required this.lessonCount,
  });

  final int id;
  final String slug;
  final String name;
  final String description;
  final String icon;
  final String imageUrl;
  final int lessonCount;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      lessonCount: json['lesson_count'] as int? ?? 0,
    );
  }
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.imageUrl,
    required this.wordCount,
    this.words = const [],
  });

  final int id;
  final String title;
  final String description;
  final String difficulty;
  final String imageUrl;
  final int wordCount;
  final List<Word> words;

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'BEGINNER',
      imageUrl: json['image_url'] as String? ?? '',
      wordCount: json['word_count'] as int? ?? 0,
      words:
          (json['words'] as List?)
              ?.map((w) => Word.fromJson((w as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
    );
  }
}

class Word {
  const Word({
    required this.id,
    required this.text,
    required this.meaning,
    required this.exampleSentence,
    required this.imageUrl,
    required this.audioUrl,
  });

  final int id;
  final String text;
  final String meaning;
  final String exampleSentence;
  final String imageUrl;

  /// Pre-recorded audio. Empty means fall back to text-to-speech.
  final String audioUrl;

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] as int,
      text: json['text'] as String? ?? '',
      meaning: json['meaning'] as String? ?? '',
      exampleSentence: json['example_sentence'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      audioUrl: json['audio_url'] as String? ?? '',
    );
  }
}

/// One multiple-choice round for the Listen and Quiz modes.
class QuizRound {
  const QuizRound({
    required this.word,
    required this.options,
    required this.correctOptionId,
  });

  final Word word;
  final List<Word> options;
  final int correctOptionId;

  bool isCorrect(int optionId) => optionId == correctOptionId;

  factory QuizRound.fromJson(Map<String, dynamic> json) {
    return QuizRound(
      word: Word.fromJson((json['word'] as Map).cast<String, dynamic>()),
      options: (json['options'] as List)
          .map((o) => Word.fromJson((o as Map).cast<String, dynamic>()))
          .toList(),
      correctOptionId: json['correct_option_id'] as int,
    );
  }
}
