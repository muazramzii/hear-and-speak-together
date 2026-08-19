import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/content.dart';

/// The picture for a word, with a defined fallback order.
///
/// Illustration, then emoji, then a generic icon. The emoji step is what keeps
/// a Listen round answerable when no artwork has been supplied: the word is
/// hidden in that mode, so without something distinguishing, all four options
/// would render identically and the question could only be guessed.
class WordVisual extends StatelessWidget {
  const WordVisual({
    super.key,
    required this.word,
    this.size = 64,
    this.fit = BoxFit.contain,
  });

  final Word word;

  /// Drives the emoji and fallback-icon size; images fill their box.
  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (word.imageUrl.isNotEmpty) {
      return Image.network(
        word.imageUrl,
        fit: fit,
        // A broken image must not leave the tile blank - fall through to the
        // emoji rather than showing nothing.
        errorBuilder: (_, _, _) => _EmojiOrIcon(word: word, size: size),
      );
    }

    return _EmojiOrIcon(word: word, size: size);
  }
}

class _EmojiOrIcon extends StatelessWidget {
  const _EmojiOrIcon({required this.word, required this.size});

  final Word word;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (word.emoji.isEmpty) {
      return Center(
        child: Icon(
          Icons.image_outlined,
          size: size * 0.75,
          color: AppColors.textSecondary,
        ),
      );
    }

    // Hidden from screen readers: the surrounding tile already announces the
    // word, and hearing "cat face" over it is noise.
    return ExcludeSemantics(
      child: Center(child: Text(word.emoji, style: TextStyle(fontSize: size))),
    );
  }
}
