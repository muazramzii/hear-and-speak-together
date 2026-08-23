class LanguageInfo {
  const LanguageInfo({
    required this.id,
    required this.code,
    required this.name,
    required this.locale,
    required this.ttsVoice,
  });

  final int id;
  final String code;
  final String name;
  final String locale;
  final String ttsVoice;

  factory LanguageInfo.fromJson(Map<String, dynamic> json) {
    return LanguageInfo(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String? ?? '',
      locale: json['locale'] as String? ?? '',
      ttsVoice: json['tts_voice'] as String? ?? '',
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
    this.lessonIds = const [],
  });

  final int id;
  final String slug;
  final String name;
  final String description;
  final String icon;
  final String imageUrl;
  final int lessonCount;

  /// Only populated from the category *detail* endpoint (`/categories/:id/`),
  /// which nests the category's lessons - the plain list endpoint has no
  /// `lessons` key, so this stays empty there.
  final List<int> lessonIds;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      lessonCount: json['lesson_count'] as int? ?? 0,
      lessonIds:
          (json['lessons'] as List?)
              ?.map((l) => (l as Map)['id'] as int)
              .toList() ??
          const [],
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
    required this.emoji,
    required this.audioUrl,
  });

  final int id;
  final String text;
  final String meaning;
  final String exampleSentence;
  final String imageUrl;

  /// Stands in for a missing illustration. Without it a Listen round is
  /// unplayable: the word is hidden, so every option would look identical.
  final String emoji;

  bool get hasVisual => imageUrl.isNotEmpty || emoji.isNotEmpty;

  /// Pre-recorded audio. Empty means fall back to text-to-speech.
  final String audioUrl;

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] as int,
      text: json['text'] as String? ?? '',
      meaning: json['meaning'] as String? ?? '',
      exampleSentence: json['example_sentence'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '',
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
      options:
          (json['options'] as List)
              .map((o) => Word.fromJson((o as Map).cast<String, dynamic>()))
              .toList(),
      correctOptionId: json['correct_option_id'] as int,
    );
  }
}
