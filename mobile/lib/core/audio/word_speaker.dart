import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks the target word aloud so the child hears it before trying.
///
/// On-device TTS is used rather than Azure's, because this fires every time a
/// child taps "listen" - often several times per word. Routing that through a
/// paid API would multiply cost for no pedagogical gain, and it would stop
/// working offline.
class WordSpeaker {
  WordSpeaker(this._tts);

  final FlutterTts _tts;

  static const _localeFor = {'en': 'en-US', 'ms': 'ms-MY'};

  /// Half speed, for the "say it slowly" control. Children learning a sound
  /// need to hear its parts.
  static const _slowRate = 0.3;
  static const _normalRate = 0.45;

  Future<void> speak(
    String text, {
    required String languageCode,
    bool slow = false,
  }) async {
    final locale = _localeFor[languageCode] ?? 'en-US';

    await _tts.stop();
    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(slow ? _slowRate : _normalRate);
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  /// Whether the device actually has a voice for this language.
  ///
  /// Malay TTS is not installed on every Android device, so the UI must be
  /// able to hide the listen button rather than offer one that does nothing.
  Future<bool> isLanguageAvailable(String languageCode) async {
    final locale = _localeFor[languageCode] ?? 'en-US';
    try {
      final available = await _tts.isLanguageAvailable(locale);
      return available == true;
    } on Exception {
      return false;
    }
  }

  Future<void> stop() => _tts.stop();
}

final wordSpeakerProvider = Provider<WordSpeaker>((ref) {
  final speaker = WordSpeaker(FlutterTts());
  ref.onDispose(speaker.stop);
  return speaker;
});
