import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../providers/practice_provider.dart';
import '../../repositories/content_repository.dart';
import 'practice_screen.dart';

/// Walks a child through a lesson's words in Speak mode.
///
/// `PracticeScreen` handles a single word; this owns which word that is, so
/// the assessment logic stays unaware of lesson structure.
class SpeakLessonScreen extends ConsumerStatefulWidget {
  const SpeakLessonScreen({
    super.key,
    required this.lessonId,
    required this.languageCode,
  });

  final int lessonId;
  final String languageCode;

  @override
  ConsumerState<SpeakLessonScreen> createState() => _SpeakLessonScreenState();
}

class _SpeakLessonScreenState extends ConsumerState<SpeakLessonScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final lesson = ref.watch(lessonProvider(widget.lessonId));

    return lesson.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              error is ApiException
                  ? error.message
                  : context.l10n.errorGeneric,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
      data: (data) {
        if (data.words.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(context.l10n.learnNoWords)),
          );
        }

        final index = _index.clamp(0, data.words.length - 1);
        final hasNext = index < data.words.length - 1;

        return PracticeScreen(
          // Rebuilding under a new key resets the practice state machine, so
          // the previous word's score can never linger on the next word.
          key: ValueKey(data.words[index].id),
          word: data.words[index],
          languageCode: widget.languageCode,
          progressLabel: '${index + 1} / ${data.words.length}',
          onNextWord: hasNext
              ? () {
                  ref.read(practiceControllerProvider.notifier).reset();
                  setState(() => _index = index + 1);
                }
              : null,
        );
      },
    );
  }
}
