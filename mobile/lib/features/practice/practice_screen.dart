import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/audio/audio_recorder.dart';
import '../../core/audio/word_speaker.dart';
import '../../theme/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../l10n/l10n.dart';
import '../../models/content.dart';
import '../../models/practice_result.dart';
import '../../providers/practice_provider.dart';
import '../../repositories/profile_repository.dart';
import '../../widgets/word_visual.dart';

/// The Speak (AI) screen: hear the word, say it, get scored - and the
/// Pronunciation Result view once it is. Both live in this one screen
/// because the result is shown in place, right where the recording
/// happened, rather than as a separate pushed route.
///
/// Every stage is announced in text as well as through animation. This is a
/// speech app used by children who may have hearing difficulty, so state must
/// never be conveyed by sound or motion alone.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({
    super.key,
    required this.word,
    required this.languageCode,
    this.progressLabel,
    this.onNextWord,
  });

  final Word word;
  final String languageCode;

  /// e.g. "3 / 12". Null when practising a single word outside a lesson.
  final String? progressLabel;

  /// Null on the last word of a lesson, which hides the "Next Word" action.
  final VoidCallback? onNextWord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(practiceControllerProvider);
    final profile = ref.watch(activeProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.l10n.speakTitle),
        actions: [
          if (progressLabel != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: Text(
                  progressLabel!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child:
                  state.stage == PracticeStage.result && state.result != null
                      ? _ResultView(
                        result: state.result!,
                        onTryAgain:
                            () =>
                                ref
                                    .read(practiceControllerProvider.notifier)
                                    .reset(),
                        onNextWord: onNextWord,
                      )
                      : _PromptView(
                        word: word,
                        languageCode: languageCode,
                        state: state,
                        profileId: profile?.id,
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PromptView extends ConsumerWidget {
  const _PromptView({
    required this.word,
    required this.languageCode,
    required this.state,
    required this.profileId,
  });

  final Word word;
  final String languageCode;
  final PracticeState state;
  final int? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(practiceControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WordCard(word: word),
        const SizedBox(height: AppSpacing.lg),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppOutlineButton(
              label: context.l10n.learnListen,
              icon: Icons.volume_up_rounded,
              expand: false,
              onPressed:
                  state.isBusy
                      ? null
                      : () => ref
                          .read(wordSpeakerProvider)
                          .speak(word.text, languageCode: languageCode),
            ),
            const SizedBox(width: AppSpacing.md),
            AppOutlineButton(
              label: context.l10n.practiceSlowly,
              icon: Icons.slow_motion_video_rounded,
              expand: false,
              onPressed:
                  state.isBusy
                      ? null
                      : () => ref
                          .read(wordSpeakerProvider)
                          .speak(
                            word.text,
                            languageCode: languageCode,
                            slow: true,
                          ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        _StageIndicator(stage: state.stage),
        const SizedBox(height: AppSpacing.lg),

        if (state.errorMessage != null || state.recordingFailure != null) ...[
          _ErrorPanel(
            // A device-side failure arrives as an enum and is translated
            // here; a server-side message arrives already worded.
            message:
                state.errorMessage ??
                _recordingMessage(context, state.recordingFailure!),
            permissionDenied: state.permissionDenied,
            onRetry: controller.reset,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        _HeroMicButton(
          stage: state.stage,
          onStart: controller.startRecording,
          onStop:
              profileId == null
                  ? null
                  : () => controller.stopAndEvaluate(
                    wordId: word.id,
                    profileId: profileId!,
                  ),
        ),

        if (profileId == null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.practiceChooseProfileFirst,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

String _recordingMessage(BuildContext context, RecordingFailure failure) {
  final l10n = context.l10n;
  return switch (failure) {
    RecordingFailure.permissionDenied => l10n.errorMicDenied,
    RecordingFailure.tooShort => l10n.errorTooShort,
    RecordingFailure.unavailable => l10n.errorMicUnavailable,
  };
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    return HeroCard(
      gradient: AppGradients.primary,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            height: 160,
            width: 160,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: WordVisual(word: word, size: 88),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            word.text.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppTypography.celebration.copyWith(
              color: Colors.white,
              letterSpacing: 1.5,
              fontSize: 30,
            ),
          ),
          if (word.meaning.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              word.meaning,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StageIndicator extends StatelessWidget {
  const _StageIndicator({required this.stage});

  final PracticeStage stage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, detail, color) = switch (stage) {
      PracticeStage.ready => (
        l10n.practiceReady,
        l10n.practiceReadyDetail,
        AppColors.textSecondary,
      ),
      PracticeStage.listening => (
        l10n.practiceListening,
        l10n.practiceListeningDetail,
        AppColors.primary,
      ),
      PracticeStage.processing => (
        l10n.practiceProcessing,
        l10n.practiceProcessingDetail,
        AppColors.blue,
      ),
      PracticeStage.error => (
        l10n.practiceFailed,
        l10n.practiceFailedDetail,
        AppColors.error,
      ),
      PracticeStage.result => (l10n.practiceResult, '', AppColors.success),
    };

    return Column(
      children: [
        if (stage == PracticeStage.processing)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: color),
        ),
        if (detail.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

/// The hero microphone, on top of the reusable `AppMicButton` from the
/// design system - this screen only maps its own `PracticeStage` onto
/// `AppMicButtonState` and adds the caption underneath. The pulse
/// animation, gradient and icon per state all live in the shared widget
/// now, not duplicated here.
class _HeroMicButton extends StatelessWidget {
  const _HeroMicButton({
    required this.stage,
    required this.onStart,
    required this.onStop,
  });

  final PracticeStage stage;
  final VoidCallback onStart;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final listening = stage == PracticeStage.listening;
    final processing = stage == PracticeStage.processing;
    final micState = switch (stage) {
      PracticeStage.listening => AppMicButtonState.listening,
      PracticeStage.processing => AppMicButtonState.loading,
      _ => AppMicButtonState.normal,
    };

    return Column(
      children: [
        AppMicButton(
          state: micState,
          diameter: 132,
          normalSemanticLabel: context.l10n.practiceStartRecording,
          listeningSemanticLabel: context.l10n.practiceStopRecording,
          onPressed: processing ? null : (listening ? onStop : onStart),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          listening
              ? context.l10n.practiceTapToStop
              : context.l10n.practiceTapToStart,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        // The visual equivalent of "the microphone is capturing sound right
        // now" - this app's users may not be able to rely on audio alone to
        // know recording is live. Stays mounted (just inactive) outside the
        // listening state so it never pops the layout.
        const SizedBox(height: AppSpacing.sm),
        AppSoundWave(active: listening),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.permissionDenied,
    required this.onRetry,
  });

  final String message;
  final bool permissionDenied;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (permissionDenied)
            // Retrying is pointless once permission is denied - the fix lives
            // in system settings.
            AppPrimaryButton(
              label: context.l10n.practiceOpenSettings,
              onPressed: openAppSettings,
            )
          else
            AppPrimaryButton(
              label: context.l10n.actionTryAgain,
              onPressed: onRetry,
            ),
        ],
      ),
    );
  }
}

/// The Pronunciation Result: celebrates what went well rather than grading
/// what didn't. Every score band gets a warm mascot reaction and the
/// server's own encouraging, per-language feedback sentence - never a "you
/// failed" red treatment, even for a low score.
class _ResultView extends StatefulWidget {
  const _ResultView({
    required this.result,
    required this.onTryAgain,
    this.onNextWord,
  });

  final PracticeResult result;
  final VoidCallback onTryAgain;
  final VoidCallback? onNextWord;

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  bool _celebrate = false;

  @override
  void initState() {
    super.initState();
    // Deferred one frame so the burst originates from an already-laid-out
    // screen rather than competing with the first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final score = widget.result.score;
      if (score != null && score >= 75) {
        setState(() => _celebrate = true);
      }
    });
  }

  MascotState get _mood =>
      widget.result.heardSpeech
          ? MascotEmotion.forScore(widget.result.score)
          : MascotEmotion.busy;

  Color get _ringColor {
    final score = widget.result.score ?? 0;
    if (score >= 90) return AppColors.greenStrong;
    if (score >= 75) return AppColors.blueStrong;
    if (score >= 50) return AppColors.amber;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child:
                  result.heardSpeech
                      ? CircularScore(
                        value: (result.score ?? 0) / 100,
                        color: _ringColor,
                        child: ScoreCountUp(
                          value: result.score ?? 0,
                          style: AppTypography.display.copyWith(
                            color: _ringColor,
                          ),
                        ),
                      )
                      : Mascot(state: _mood, size: 120),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (result.heardSpeech) ...[
              Center(child: Mascot(state: _mood, size: 64)),
              const SizedBox(height: AppSpacing.md),
            ],

            Center(child: MascotSpeechBubble(text: result.feedback)),
            const SizedBox(height: AppSpacing.md),

            if (result.heardSpeech && result.recognizedText.isNotEmpty) ...[
              Text(
                context.l10n.practiceYouSaid('"${result.recognizedText}"'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            if (result.heardSpeech) ...[
              _DetailScores(result: result),
              const SizedBox(height: AppSpacing.md),
            ],

            if (result.pointsAwarded > 0)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amberSoft,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+${result.pointsAwarded}',
                        style: const TextStyle(
                          color: AppColors.textOnAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.lg),
            if (widget.onNextWord != null) ...[
              AppPrimaryButton(
                label: context.l10n.actionTryAgain,
                onPressed: widget.onTryAgain,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppSecondaryButton(
                label: context.l10n.practiceNextWord,
                icon: Icons.arrow_forward_rounded,
                onPressed: widget.onNextWord,
              ),
            ] else
              AppPrimaryButton(
                label: context.l10n.actionTryAgain,
                onPressed: widget.onTryAgain,
              ),
          ],
        ),
        // No message here - the mascot's speech bubble above already carries
        // `result.feedback` persistently; the overlay only adds the confetti
        // + celebratory mascot pop so the two don't compete for the same
        // line of text.
        Positioned.fill(child: CelebrationOverlay(active: _celebrate)),
      ],
    );
  }
}

/// The similarity / confidence / completeness breakdown behind the headline
/// score. Every attempt carries all three - there is no per-locale gating in
/// this architecture, unlike the previous Azure-backed version.
class _DetailScores extends StatelessWidget {
  const _DetailScores({required this.result});

  final PracticeResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = <(String, double?, Color)>[
      (l10n.metricSimilarity, result.similarity, AppColors.primary),
      (l10n.metricConfidence, result.confidence, AppColors.blueStrong),
      (l10n.metricCompleteness, result.completeness, AppColors.greenStrong),
    ];

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          for (final (label, value, color) in rows)
            if (value != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          '${value.round()}%',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    LinearProgressBar(
                      value: value / 100,
                      color: color,
                      height: 8,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
