import 'package:flutter/material.dart';

import '../../../models/content.dart';
import '../../../widgets/app_widgets.dart';
import '../../../widgets/word_visual.dart';

/// The picture for a word in the lesson flow, with one more fallback step
/// than the bare `WordVisual`: a word with no illustration and no emoji
/// shows the mascot instead of a generic "missing image" icon, so a gap in
/// content never reads as a broken screen to a child.
class WordIllustration extends StatelessWidget {
  const WordIllustration({
    super.key,
    required this.word,
    this.size = 96,
    this.fit = BoxFit.contain,
  });

  final Word word;
  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (!word.hasVisual) {
      return Mascot(state: MascotState.idle, size: size);
    }
    return WordVisual(word: word, size: size, fit: fit);
  }
}
