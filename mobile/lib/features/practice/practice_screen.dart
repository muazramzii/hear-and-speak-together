import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/audio/word_speaker.dart';
import '../../core/theme/app_theme.dart';
import '../../models/content.dart';
import '../../models/practice_result.dart';
import '../../providers/practice_provider.dart';
import '../../repositories/profile_repository.dart';
import 'widgets/score_gauge.dart';

/// The Speak (AI) screen: hear the word, say it, get scored.
///
/// Every stage is announced in text as well as through animation. This is a
/// speech app used by children who may have hearing difficulty, so state must
/// never be conveyed by sound or motion alone.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({
    super.key,
    required this.word,
    required this.languageCode,
  });

  final Word word;
  final String languageCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(practiceControllerProvider);
    final profile = ref.watch(activeProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Speak (AI)')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: state.stage == PracticeStage.result && state.result != null
                  ? _ResultView(
                      result: state.result!,
                      onTryAgain: () =>
                          ref.read(practiceControllerProvider.notifier).reset(),
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
            OutlinedButton.icon(
              onPressed: state.isBusy
                  ? null
                  : () => ref
                        .read(wordSpeakerProvider)
                        .speak(word.text, languageCode: languageCode),
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('Listen'),
            ),
            const SizedBox(width: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: state.isBusy
                  ? null
                  : () => ref
                        .read(wordSpeakerProvider)
                        .speak(
                          word.text,
                          languageCode: languageCode,
                          slow: true,
                        ),
              icon: const Icon(Icons.slow_motion_video_rounded),
              label: const Text('Slowly'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        _StageIndicator(stage: state.stage),
        const SizedBox(height: AppSpacing.lg),

        if (state.errorMessage != null) ...[
          _ErrorPanel(
            message: state.errorMessage!,
            permissionDenied: state.permissionDenied,
            onRetry: controller.reset,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        _MicrophoneButton(
          stage: state.stage,
          onStart: controller.startRecording,
          onStop: profileId == null
              ? null
              : () => controller.stopAndEvaluate(
                  wordId: word.id,
                  profileId: profileId!,
                ),
        ),

        if (profileId == null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Choose a profile before practising.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.violetSoft,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        children: [
          if (word.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              child: Image.network(
                word.imageUrl,
                height: 140,
                fit: BoxFit.contain,
                // A missing illustration must not break the exercise - the
                // word itself is what matters.
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            )
          else
            const Icon(
              Icons.image_outlined,
              size: 72,
              color: AppColors.textSecondary,
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            word.text.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: AppColors.primary,
              letterSpacing: 1.5,
            ),
          ),
          if (word.meaning.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              word.meaning,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
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
    final (label, detail, color) = switch (stage) {
      PracticeStage.ready => (
        'Ready',
        'Tap the microphone and say the word.',
        AppColors.textSecondary,
      ),
      PracticeStage.listening => (
        'Listening...',
        'Say the word, then tap to stop.',
        AppColors.primary,
      ),
      PracticeStage.processing => (
        'Checking your pronunciation...',
        'This takes a moment.',
        AppColors.blue,
      ),
      PracticeStage.error => (
        'Something went wrong',
        'See the message below.',
        AppColors.danger,
      ),
      PracticeStage.result => ('Result', '', AppColors.success),
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

class _MicrophoneButton extends StatelessWidget {
  const _MicrophoneButton({
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

    return Column(
      children: [
        Semantics(
          button: true,
          label: listening ? 'Stop recording' : 'Start recording',
          child: GestureDetector(
            onTap: processing ? null : (listening ? onStop : onStart),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 96,
              width: 96,
              decoration: BoxDecoration(
                color: processing
                    ? AppColors.border
                    : (listening ? AppColors.danger : AppColors.primary),
                shape: BoxShape.circle,
              ),
              child: Icon(
                listening ? Icons.stop_rounded : Icons.mic_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          listening ? 'Tap to stop' : 'Tap to start speaking',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
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
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
              ),
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
            FilledButton(
              onPressed: openAppSettings,
              child: const Text('Open Settings'),
            )
          else
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

class _ResultView extends StatefulWidget {
  const _ResultView({required this.result, required this.onTryAgain});

  final PracticeResult result;
  final VoidCallback onTryAgain;

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!result.heardSpeech)
          const Icon(
            Icons.hearing_disabled_rounded,
            size: 72,
            color: AppColors.textSecondary,
          )
        else
          Center(child: ScoreGauge(score: result.score ?? 0)),
        const SizedBox(height: AppSpacing.lg),

        Text(
          result.feedback,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),

        if (result.heardSpeech && result.recognizedText.isNotEmpty) ...[
          Text(
            'You said: "${result.recognizedText}"',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        if (result.pointsAwarded > 0)
          Center(
            child: Chip(
              avatar: const Icon(
                Icons.star_rounded,
                color: AppColors.amber,
                size: 18,
              ),
              label: Text('+${result.pointsAwarded}'),
            ),
          ),
        const SizedBox(height: AppSpacing.md),

        for (final tip in result.tips) _TipRow(tip: tip),

        if (result.displayableScores.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => setState(() => _showDetails = !_showDetails),
            child: Text(_showDetails ? 'Hide Details' : 'View Details'),
          ),
          if (_showDetails) _DetailScores(result: result),
        ],

        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: widget.onTryAgain,
          child: const Text('Try Again'),
        ),
      ],
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.tip});

  final PracticeTip tip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: tip.isPositive ? AppColors.greenSoft : AppColors.amberSoft,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        child: Row(
          children: [
            Icon(
              tip.isPositive
                  ? Icons.check_circle_rounded
                  : Icons.lightbulb_outline_rounded,
              color: tip.isPositive ? AppColors.success : AppColors.warning,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                tip.text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The technical breakdown, behind "View Details".
///
/// It renders only metrics the backend says this locale can measure. Azure
/// does not assess prosody for ms-MY, so no intonation row appears for a
/// Malay word - showing one would be inventing a measurement.
class _DetailScores extends StatelessWidget {
  const _DetailScores({required this.result});

  final PracticeResult result;

  static const _labels = {
    'accuracy': 'Accuracy',
    'fluency': 'Fluency',
    'completeness': 'Completeness',
    'pronunciation': 'Pronunciation',
    'prosody': 'Intonation',
  };

  @override
  Widget build(BuildContext context) {
    final scores = result.displayableScores;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            for (final entry in scores.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _labels[entry.key] ?? entry.key,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${entry.value.round()}%',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Scored by Azure AI Speech for ${result.locale}.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
