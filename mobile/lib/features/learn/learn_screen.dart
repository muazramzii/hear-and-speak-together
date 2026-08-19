import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/word_speaker.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/content.dart';
import '../../repositories/content_repository.dart';
import '../../widgets/word_visual.dart';

/// Learn mode: browse a lesson's words one card at a time, hearing each.
///
/// No scoring and no microphone - this is the step before practising, where a
/// child just meets the word.
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({
    super.key,
    required this.lessonId,
    required this.languageCode,
  });

  final int lessonId;
  final String languageCode;

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = ref.watch(lessonProvider(widget.lessonId));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.learnTitle)),
      body: SafeArea(
        child: lesson.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: error is ApiException
                ? error.message
                : context.l10n.errorGeneric,
            onRetry: () => ref.invalidate(lessonProvider(widget.lessonId)),
          ),
          data: (data) => data.words.isEmpty
              ? Center(child: Text(context.l10n.learnNoWords))
              : _WordPager(
                  words: data.words,
                  controller: _pageController,
                  index: _index,
                  languageCode: widget.languageCode,
                  onIndexChanged: (value) => setState(() => _index = value),
                ),
        ),
      ),
    );
  }
}

class _WordPager extends ConsumerWidget {
  const _WordPager({
    required this.words,
    required this.controller,
    required this.index,
    required this.languageCode,
    required this.onIndexChanged,
  });

  final List<Word> words;
  final PageController controller;
  final int index;
  final String languageCode;
  final ValueChanged<int> onIndexChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: controller,
            itemCount: words.length,
            onPageChanged: onIndexChanged,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _WordCard(
                    word: words[i],
                    languageCode: languageCode,
                  ),
                ),
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
                  IconButton.filledTonal(
                    onPressed: index == 0
                        ? null
                        : () => controller.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: context.l10n.learnPrevious,
                  ),
                  Text(
                    '${index + 1} / ${words.length}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  IconButton.filledTonal(
                    onPressed: index >= words.length - 1
                        ? null
                        : () => controller.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: context.l10n.learnNext,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (index + 1) / words.length,
                  backgroundColor: AppColors.border,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WordCard extends ConsumerWidget {
  const _WordCard({required this.word, required this.languageCode});

  final Word word;
  final String languageCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.blueSoft,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              child: WordVisual(word: word, size: 96, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            word.text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (word.meaning.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              word.meaning,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                iconSize: 32,
                padding: const EdgeInsets.all(AppSpacing.md),
                onPressed: () => ref
                    .read(wordSpeakerProvider)
                    .speak(word.text, languageCode: languageCode),
                icon: const Icon(Icons.volume_up_rounded),
                tooltip: context.l10n.learnListen,
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton.filledTonal(
                iconSize: 28,
                padding: const EdgeInsets.all(AppSpacing.md),
                onPressed: () => ref
                    .read(wordSpeakerProvider)
                    .speak(word.text, languageCode: languageCode, slow: true),
                icon: const Icon(Icons.slow_motion_video_rounded),
                tooltip: context.l10n.learnListenSlowly,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: AppColors.danger,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.actionTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
