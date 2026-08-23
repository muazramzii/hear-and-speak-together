import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/word_speaker.dart';
import '../../l10n/l10n.dart';
import '../../models/content.dart';
import '../../providers/choice_session_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/word_visual.dart';

/// Called once, when the last round has been answered and the run has been
/// submitted - `pointsAwarded` prefers the server-confirmed total and only
/// falls back to the client-side estimate if submission was swallowed (no
/// profile, or a network failure - see `ChoiceSessionController`).
typedef QuizFinishedCallback =
    void Function({
      required int correct,
      required int total,
      required int pointsAwarded,
      required List<String> newAchievements,
    });

/// Screen 4 of the guided lesson flow: image-first multiple choice, reusing
/// the same session/scoring logic as the standalone Quiz mode
/// (`choiceSessionProvider`) but with its own view so the standalone
/// `/quiz/:lessonId` route stays untouched.
class QuizStageView extends ConsumerWidget {
  const QuizStageView({
    super.key,
    required this.lessonId,
    required this.languageCode,
    required this.onFinished,
  });

  final int lessonId;
  final String languageCode;
  final QuizFinishedCallback onFinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ChoiceSessionArgs(lessonId: lessonId, mode: ChoiceMode.quiz);
    final state = ref.watch(choiceSessionProvider(args));
    final controller = ref.read(choiceSessionProvider(args).notifier);

    Future<void> handleNext() async {
      final wasLastRound = state.isLastRound;
      await controller.next();
      if (!wasLastRound) return;

      final result = ref.read(choiceSessionProvider(args));
      onFinished(
        correct: result.correctCount,
        total: result.totalRounds,
        pointsAwarded: result.pointsAwarded ?? controller.pointsEarned,
        newAchievements: result.newAchievements,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(context.l10n.quizTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: switch (state.stage) {
              ChoiceStage.error => _ErrorView(
                message:
                    state.errorMessage ??
                    switch (state.errorCode) {
                      ChoiceError.notEnoughWords =>
                        context.l10n.choiceNotEnoughWords,
                      null => context.l10n.errorGeneric,
                    },
                onRetry: controller.start,
              ),
              // Finished: the round the last answer belongs to is still
              // shown for an instant while submission completes and the
              // parent flow swaps to Celebration.
              ChoiceStage.finished => const Center(
                child: CircularProgressIndicator(),
              ),
              _ => _QuizRoundView(
                state: state,
                languageCode: languageCode,
                onAnswer: controller.answer,
                onNext: handleNext,
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _QuizRoundView extends ConsumerWidget {
  const _QuizRoundView({
    required this.state,
    required this.languageCode,
    required this.onAnswer,
    required this.onNext,
  });

  final ChoiceSessionState state;
  final String languageCode;
  final void Function(int) onAnswer;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final round = state.round;
    final l10n = context.l10n;

    if (state.stage == ChoiceStage.loading || round == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.choiceQuestionOf(state.roundNumber, state.totalRounds),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressBar(value: state.progress),
          const SizedBox(height: AppSpacing.lg),

          Text(
            l10n.choicePromptQuiz,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),

          Center(
            child: AppIconButton(
              icon: Icons.volume_up_rounded,
              filled: true,
              size: 72,
              semanticLabel: l10n.choicePlayWord,
              onPressed:
                  () => ref
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
                  tone: _toneFor(option, round),
                  showLabel: state.hasAnswered,
                  onTap: state.hasAnswered ? null : () => onAnswer(option.id),
                ),
            ],
          ),

          if (state.hasAnswered) ...[
            const SizedBox(height: AppSpacing.lg),
            _AnswerBanner(correct: state.lastAnswerCorrect),
            const SizedBox(height: AppSpacing.md),
            AppPrimaryButton(
              label: state.isLastRound ? l10n.choiceFinish : l10n.choiceNext,
              icon:
                  state.isLastRound
                      ? Icons.celebration_rounded
                      : Icons.arrow_forward_rounded,
              onPressed: onNext,
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

enum _OptionTone { neutral, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.tone,
    required this.showLabel,
    required this.onTap,
  });

  final Word option;
  final _OptionTone tone;
  final bool showLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (border, fill, icon) = switch (tone) {
      _OptionTone.correct => (
        AppColors.success,
        AppColors.greenSoft,
        Icons.check_circle_rounded,
      ),
      _OptionTone.wrong => (
        AppColors.error,
        AppColors.pinkSoft,
        Icons.cancel_rounded,
      ),
      _OptionTone.neutral => (AppColors.border, AppColors.surface, null),
    };

    return Semantics(
      button: onTap != null,
      label: switch (tone) {
        _OptionTone.correct => context.l10n.choiceCorrectAnswer(option.text),
        _OptionTone.wrong => context.l10n.choiceWrongAnswer(option.text),
        _OptionTone.neutral => option.text,
      },
      child: AppPressable(
        onTap: onTap,
        enabled: onTap != null,
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: border, width: 2),
            boxShadow: AppShadows.small,
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: WordVisual(word: option, size: 56)),
              if (showLabel) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  option.text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              if (icon != null) Icon(icon, color: border, size: 22),
            ],
          ),
        ),
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
        borderRadius: BorderRadius.circular(AppRadius.medium),
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
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

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
            color: AppColors.error,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
            label: context.l10n.actionTryAgain,
            expand: false,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
