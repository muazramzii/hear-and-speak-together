import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/word_speaker.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/content.dart';
import '../../providers/choice_session_provider.dart';

/// Serves both Listen ("hear the sound, pick the picture") and Quiz.
///
/// The two modes differ only in whether the word is shown in text: hiding it
/// is the whole point of a listening exercise, because a child who can read
/// the word does not need to hear it.
class ChoiceRoundScreen extends ConsumerWidget {
  const ChoiceRoundScreen({
    super.key,
    required this.lessonId,
    required this.mode,
    required this.languageCode,
  });

  final int lessonId;
  final ChoiceMode mode;
  final String languageCode;

  bool get _isListen => mode == ChoiceMode.listen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ChoiceSessionArgs(lessonId: lessonId, mode: mode);
    final state = ref.watch(choiceSessionProvider(args));
    final controller = ref.read(choiceSessionProvider(args).notifier);

    return Scaffold(
      appBar: AppBar(title: Text(_isListen ? context.l10n.listenTitle : context.l10n.quizTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: switch (state.stage) {
              ChoiceStage.error => _ErrorState(
                message:
                    state.errorMessage ??
                    switch (state.errorCode) {
                      ChoiceError.notEnoughWords =>
                        context.l10n.choiceNotEnoughWords,
                      null => context.l10n.errorGeneric,
                    },
                onRetry: controller.start,
              ),
              ChoiceStage.finished => _FinishedState(
                correct: state.correctCount,
                total: state.totalRounds,
                points: controller.pointsEarned,
                onPlayAgain: controller.start,
              ),
              _ => _RoundView(
                state: state,
                isListen: _isListen,
                languageCode: languageCode,
                onAnswer: controller.answer,
                onNext: controller.next,
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _RoundView extends ConsumerWidget {
  const _RoundView({
    required this.state,
    required this.isListen,
    required this.languageCode,
    required this.onAnswer,
    required this.onNext,
  });

  final ChoiceSessionState state;
  final bool isListen;
  final String languageCode;
  final void Function(int) onAnswer;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final round = state.round;

    if (state.stage == ChoiceStage.loading || round == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProgressHeader(state: state),
          const SizedBox(height: AppSpacing.lg),

          Text(
            isListen
                ? context.l10n.choicePromptListen
                : context.l10n.choicePromptQuiz,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),

          // In Quiz the word is written as well as spoken; in Listen it is
          // spoken only.
          if (!isListen)
            Text(
              round.word.text.toUpperCase(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.2,
              ),
            ),
          const SizedBox(height: AppSpacing.md),

          Center(
            child: _SpeakerButton(
              onPressed: () => ref
                  .read(wordSpeakerProvider)
                  .speak(round.word.text, languageCode: languageCode),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.05,
            children: [
              for (final option in round.options)
                _OptionTile(
                  option: option,
                  state: _toneFor(option, round),
                  showLabel: isListen || state.hasAnswered,
                  onTap: state.hasAnswered ? null : () => onAnswer(option.id),
                ),
            ],
          ),

          if (state.hasAnswered) ...[
            const SizedBox(height: AppSpacing.lg),
            _AnswerBanner(correct: state.lastAnswerCorrect),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onNext,
              child: Text(
              state.isLastRound
                  ? context.l10n.choiceFinish
                  : context.l10n.choiceNext,
            ),
            ),
          ],
        ],
      ),
    );
  }

  _OptionTone _toneFor(Word option, QuizRound round) {
    if (!state.hasAnswered) return _OptionTone.neutral;
    if (round.isCorrect(option.id)) return _OptionTone.correct;
    if (state.selectedOptionId == option.id) return _OptionTone.wrong;
    return _OptionTone.neutral;
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.state});

  final ChoiceSessionState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          context.l10n.choiceQuestionOf(
            state.roundNumber,
            state.totalRounds,
          ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: state.progress,
            backgroundColor: AppColors.border,
          ),
        ),
      ],
    );
  }
}

class _SpeakerButton extends StatelessWidget {
  const _SpeakerButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.choicePlayWord,
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            height: 72,
            width: 72,
            child: Icon(
              Icons.volume_up_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

enum _OptionTone { neutral, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.state,
    required this.showLabel,
    required this.onTap,
  });

  final Word option;
  final _OptionTone state;
  final bool showLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (border, fill, icon) = switch (state) {
      _OptionTone.correct => (
        AppColors.success,
        AppColors.greenSoft,
        Icons.check_circle_rounded,
      ),
      _OptionTone.wrong => (
        AppColors.danger,
        AppColors.pinkSoft,
        Icons.cancel_rounded,
      ),
      _OptionTone.neutral => (AppColors.border, AppColors.surface, null),
    };

    return Semantics(
      button: onTap != null,
      // Correctness is announced, not just coloured, so the outcome is
      // available to a child using a screen reader.
      label: switch (state) {
        _OptionTone.correct => context.l10n.choiceCorrectAnswer(option.text),
        _OptionTone.wrong => context.l10n.choiceWrongAnswer(option.text),
        _OptionTone.neutral => option.text,
      },
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: border, width: 2),
            ),
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: option.imageUrl.isNotEmpty
                      ? Image.network(
                          option.imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const _ImageFallback(),
                        )
                      : const _ImageFallback(),
                ),
                if (showLabel) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    option.text,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                if (icon != null)
                  Icon(
                    icon,
                    color: border,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Illustrations are not supplied yet, so a tile without one still has to be
/// choosable - the word label carries the meaning.
class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.image_outlined,
        size: 40,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _AnswerBanner extends StatelessWidget {
  const _AnswerBanner({required this.correct});

  final bool correct;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: correct ? AppColors.greenSoft : AppColors.amberSoft,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            correct ? Icons.celebration_rounded : Icons.refresh_rounded,
            color: correct ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            correct ? context.l10n.choiceCorrect : context.l10n.choiceWrong,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (correct) ...[
            const SizedBox(width: AppSpacing.sm),
            const Text('+10 ⭐'),
          ],
        ],
      ),
    );
  }
}

class _FinishedState extends StatelessWidget {
  const _FinishedState({
    required this.correct,
    required this.total,
    required this.points,
    required this.onPlayAgain,
  });

  final int correct;
  final int total;
  final int points;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 72)),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.choiceWellDone,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.choiceScoreLine(correct, total),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Chip(
            avatar: const Icon(
              Icons.star_rounded,
              color: AppColors.amber,
              size: 18,
            ),
            label: Text('+$points'),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: onPlayAgain,
            child: Text(context.l10n.choicePlayAgain),
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}
