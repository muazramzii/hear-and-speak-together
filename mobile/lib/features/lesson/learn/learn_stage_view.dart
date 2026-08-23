import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/word_speaker.dart';
import '../../core/text/syllables.dart';
import '../../l10n/l10n.dart';
import '../../models/content.dart';
import '../../theme/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/word_visual.dart';

/// Screen 2 of the guided lesson flow: a visual flashcard per word - meet
/// the word, hear it, see it broken into syllables. No microphone; that
/// comes later, in Speak.
class LearnStageView extends ConsumerStatefulWidget {
  const LearnStageView({
    super.key,
    required this.words,
    required this.languageCode,
    required this.onComplete,
  });

  final List<Word> words;
  final String languageCode;
  final VoidCallback onComplete;

  @override
  ConsumerState<LearnStageView> createState() => _LearnStageViewState();
}

class _LearnStageViewState extends ConsumerState<LearnStageView> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == widget.words.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(context.l10n.learnTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: widget.words.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder:
                        (context, i) => Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: _LearnCard(
                            word: widget.words[i],
                            languageCode: widget.languageCode,
                          ),
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppIconButton(
                            icon: Icons.chevron_left_rounded,
                            filled: true,
                            semanticLabel: context.l10n.learnPrevious,
                            onPressed:
                                _index == 0
                                    ? null
                                    : () => _controller.previousPage(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOut,
                                    ),
                          ),
                          Text(
                            '${_index + 1} / ${widget.words.length}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          isLast
                              ? const SizedBox(width: AppSpacing.minTapTarget)
                              : AppIconButton(
                                icon: Icons.chevron_right_rounded,
                                filled: true,
                                semanticLabel: context.l10n.learnNext,
                                onPressed:
                                    () => _controller.nextPage(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOut,
                                    ),
                              ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      LinearProgressBar(
                        value: (_index + 1) / widget.words.length,
                      ),
                      if (isLast) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppPrimaryButton(
                          label: context.l10n.learnContinueToListen,
                          icon: Icons.arrow_forward_rounded,
                          onPressed: widget.onComplete,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LearnCard extends ConsumerWidget {
  const _LearnCard({required this.word, required this.languageCode});

  final Word word;
  final String languageCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syllables = splitSyllables(word.text);

    return SingleChildScrollView(
      child: AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.blueSoft,
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.large),
                child: WordVisual(word: word, size: 88, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              word.text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (syllables.length > 1) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                syllables.join(' · '),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.primary),
              ),
            ],
            if (word.meaning.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                word.meaning,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (word.exampleSentence.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                context.l10n.learnExampleLabel,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '"${word.exampleSentence}"',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIconButton(
                  icon: Icons.volume_up_rounded,
                  filled: true,
                  semanticLabel: context.l10n.learnListen,
                  onPressed:
                      () => ref
                          .read(wordSpeakerProvider)
                          .speak(word.text, languageCode: languageCode),
                ),
                const SizedBox(width: AppSpacing.md),
                AppIconButton(
                  icon: Icons.slow_motion_video_rounded,
                  filled: true,
                  semanticLabel: context.l10n.learnListenSlowly,
                  onPressed:
                      () => ref
                          .read(wordSpeakerProvider)
                          .speak(
                            word.text,
                            languageCode: languageCode,
                            slow: true,
                          ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
