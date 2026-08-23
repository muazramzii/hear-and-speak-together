import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/word_speaker.dart';
import '../../../l10n/l10n.dart';
import '../../../models/content.dart';
import '../../../providers/choice_session_provider.dart';
import '../../../theme/theme.dart';
import '../../../widgets/app_widgets.dart';
import '../widgets/word_illustration.dart';

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

/// The three image-first question shapes a round can take, cycled by round
/// number so a child never faces ten identical-looking questions in a row.
/// All three run on the exact same `QuizRound` data (a target word plus
/// options) - only which side shows a picture and which shows text changes.
enum _QuestionKind {
  /// "What is this?" - the word is spoken, the options are pictures.
  identifyPicture,

  /// The target's picture is shown; the options are words.
  matchWord,

  /// Audio only by default, with a caption a child can choose to reveal -
  /// the deliberately "hearing practice" variant.
  listenAndChoose,
}

_QuestionKind _kindForRound(int roundNumber) =>
    _QuestionKind.values[(roundNumber - 1) % _QuestionKind.values.length];

String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// Screen 5 of the guided lesson flow: image-first multiple choice, reusing
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
                // Resets the round's local playback/caption state whenever
                // the question itself changes, the same way `PracticeScreen`
                // resets under a new word key in the Speak stage.
                key: ValueKey(state.round?.word.id ?? state.roundNumber),
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

class _QuizRoundView extends ConsumerStatefulWidget {
  const _QuizRoundView({
    super.key,
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
  ConsumerState<_QuizRoundView> createState() => _QuizRoundViewState();
}

class _QuizRoundViewState extends ConsumerState<_QuizRoundView> {
  bool _isPlaying = false;
  bool _captionsOn = false;

  Future<void> _play(String text) async {
    setState(() => _isPlaying = true);
    await ref
        .read(wordSpeakerProvider)
        .speak(text, languageCode: widget.languageCode);
    if (mounted) setState(() => _isPlaying = false);
  }

  String _promptFor(AppL10n l10n, _QuestionKind kind) => switch (kind) {
    _QuestionKind.identifyPicture => l10n.quizWhatIsThis,
    _QuestionKind.matchWord => l10n.quizChooseTheWord,
    _QuestionKind.listenAndChoose => l10n.choicePromptListen,
  };

  _OptionTone _toneFor(Word option, QuizRound round) {
    if (!widget.state.hasAnswered) return _OptionTone.neutral;
    if (round.isCorrect(option.id)) return _OptionTone.correct;
    if (widget.state.selectedOptionId == option.id) return _OptionTone.wrong;
    return _OptionTone.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final round = state.round;
    final l10n = context.l10n;

    if (state.stage == ChoiceStage.loading || round == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final kind = _kindForRound(state.roundNumber);

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
            _promptFor(l10n, kind),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),

          if (kind == _QuestionKind.matchWord) ...[
            Center(
              child: Container(
                height: 140,
                width: 140,
                decoration: const BoxDecoration(
                  color: AppColors.blueSoft,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: WordIllustration(word: round.word, size: 80),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: AppIconButton(
                icon: Icons.volume_up_rounded,
                semanticLabel: l10n.choicePlayWord,
                onPressed: () => _play(round.word.text),
              ),
            ),
          ] else ...[
            Center(
              child: AppIconButton(
                icon: Icons.volume_up_rounded,
                filled: true,
                size: 72,
                semanticLabel: l10n.choicePlayWord,
                onPressed: () => _play(round.word.text),
              ),
            ),
            if (kind == _QuestionKind.listenAndChoose) ...[
              const SizedBox(height: AppSpacing.sm),
              AppSoundWave(active: _isPlaying, height: 32),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: _CaptionToggle(
                  active: _captionsOn,
                  onTap: () => setState(() => _captionsOn = !_captionsOn),
                ),
              ),
              if (_captionsOn) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  round.word.text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ],
          ],
          const SizedBox(height: AppSpacing.lg),

          if (kind == _QuestionKind.matchWord)
            Column(
              children: [
                for (final option in round.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _WordOptionTile(
                      option: option,
                      tone: _toneFor(option, round),
                      onTap:
                          state.hasAnswered
                              ? null
                              : () => widget.onAnswer(option.id),
                    ),
                  ),
              ],
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.05,
              children: [
                for (final option in round.options)
                  _PictureOptionTile(
                    option: option,
                    tone: _toneFor(option, round),
                    showLabel: state.hasAnswered,
                    onTap:
                        state.hasAnswered
                            ? null
                            : () => widget.onAnswer(option.id),
                  ),
              ],
            ),

          if (state.hasAnswered) ...[
            const SizedBox(height: AppSpacing.lg),
            _AnswerBanner(
              correct: state.lastAnswerCorrect,
              correctWord: _capitalize(round.word.text),
            ),
            const SizedBox(height: AppSpacing.md),
            AppPrimaryButton(
              label: state.isLastRound ? l10n.choiceFinish : l10n.choiceNext,
              icon:
                  state.isLastRound
                      ? Icons.celebration_rounded
                      : Icons.arrow_forward_rounded,
              onPressed: widget.onNext,
            ),
          ],
        ],
      ),
    );
  }
}

enum _OptionTone { neutral, correct, wrong }

class _CaptionToggle extends StatelessWidget {
  const _CaptionToggle({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label =
        active
            ? context.l10n.listenHideCaptions
            : context.l10n.listenShowCaptions;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: AppPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active
                    ? Icons.closed_caption_rounded
                    : Icons.closed_caption_off_rounded,
                size: 18,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PictureOptionTile extends StatelessWidget {
  const _PictureOptionTile({
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
    final (border, fill, icon) = _toneColors(tone);

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
              Expanded(child: WordIllustration(word: option, size: 56)),
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

/// The Match Word tile: the option itself is text, not a picture - used only
/// by [_QuestionKind.matchWord], where the picture is the prompt instead.
class _WordOptionTile extends StatelessWidget {
  const _WordOptionTile({
    required this.option,
    required this.tone,
    required this.onTap,
  });

  final Word option;
  final _OptionTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (border, fill, icon) = _toneColors(tone);

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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: border, width: 2),
            boxShadow: AppShadows.small,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                option.text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (icon != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(icon, color: border, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

(Color, Color, IconData?) _toneColors(_OptionTone tone) => switch (tone) {
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

/// Never tells a child they are "wrong" - a miss names the right answer
/// instead, so the moment stays informative rather than judgemental.
class _AnswerBanner extends StatelessWidget {
  const _AnswerBanner({required this.correct, required this.correctWord});

  final bool correct;
  final String correctWord;

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
            correct ? Icons.celebration_rounded : Icons.favorite_rounded,
            color: correct ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              correct
                  ? context.l10n.choiceCorrect
                  : context.l10n.quizAlmostThisIs(correctWord),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
