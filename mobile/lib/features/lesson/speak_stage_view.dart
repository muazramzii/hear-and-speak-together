import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/content.dart';
import '../../providers/practice_provider.dart';
import '../practice/practice_screen.dart';

/// Screen 4 of the guided lesson flow (Speak). Walks through the lesson's
/// words exactly like the standalone `SpeakLessonScreen`, reusing
/// `PracticeScreen` unchanged, but calls [onFinished] after the last word
/// instead of leaving the child at a dead end - the one behaviour Speaking
/// Practice itself must not be modified to add, per the Stage 3 brief, so
/// it lives here instead as a thin index wrapper around the same widget.
class SpeakStageView extends ConsumerStatefulWidget {
  const SpeakStageView({
    super.key,
    required this.words,
    required this.languageCode,
    required this.onFinished,
  });

  final List<Word> words;
  final String languageCode;
  final VoidCallback onFinished;

  @override
  ConsumerState<SpeakStageView> createState() => _SpeakStageViewState();
}

class _SpeakStageViewState extends ConsumerState<SpeakStageView> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final index = _index.clamp(0, widget.words.length - 1);
    final hasNext = index < widget.words.length - 1;

    return PracticeScreen(
      // Rebuilding under a new key resets the practice state machine, so
      // the previous word's score can never linger on the next word.
      key: ValueKey(widget.words[index].id),
      word: widget.words[index],
      languageCode: widget.languageCode,
      progressLabel: '${index + 1} / ${widget.words.length}',
      onNextWord: () {
        ref.read(practiceControllerProvider.notifier).reset();
        if (hasNext) {
          setState(() => _index = index + 1);
        } else {
          widget.onFinished();
        }
      },
    );
  }
}
