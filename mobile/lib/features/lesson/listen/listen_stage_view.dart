import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/word_speaker.dart';
import '../../../l10n/l10n.dart';
import '../../../models/content.dart';
import '../../../theme/theme.dart';
import '../../../widgets/app_widgets.dart';
import '../widgets/word_illustration.dart';

/// Screen 3 of the guided lesson flow: an interactive listening pass over
/// each word - hear it, replay it, slow it down, and choose whether the
/// written word shows as a caption. No scoring here; Quiz is where the
/// child is tested.
class ListenStageView extends ConsumerStatefulWidget {
  const ListenStageView({
    super.key,
    required this.words,
    required this.languageCode,
    required this.onComplete,
  });

  final List<Word> words;
  final String languageCode;
  final VoidCallback onComplete;

  @override
  ConsumerState<ListenStageView> createState() => _ListenStageViewState();
}

class _ListenStageViewState extends ConsumerState<ListenStageView> {
  int _index = 0;
  // Captions default on: this app's users cannot always rely on audio
  // alone, so the written word is visible unless a child deliberately
  // hides it, not the other way around.
  bool _captionsOn = true;
  bool _slow = false;
  bool _isPlaying = false;

  Word get _word => widget.words[_index];
  bool get _isLast => _index == widget.words.length - 1;

  Future<void> _play() async {
    setState(() => _isPlaying = true);
    await ref
        .read(wordSpeakerProvider)
        .speak(
          _word.text,
          languageCode: widget.languageCode,
          rate: _slow ? 0.75 : null,
        );
    if (mounted) setState(() => _isPlaying = false);
  }

  void _goTo(int index) {
    setState(() {
      _index = index;
      _captionsOn = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.listenTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_index + 1} / ${widget.words.length}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LinearProgressBar(value: (_index + 1) / widget.words.length),
                  const SizedBox(height: AppSpacing.xl),

                  Center(
                    child: Container(
                      height: 180,
                      width: 180,
                      decoration: const BoxDecoration(
                        color: AppColors.blueSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: WordIllustration(word: _word, size: 96),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppSoundWave(active: _isPlaying, height: 40),
                  const SizedBox(height: AppSpacing.sm),
                  // The visual equivalent of "audio is playing" is never
                  // enough on its own for this app's users - the state is
                  // always spelled out in text too.
                  Text(
                    _isPlaying ? l10n.practiceListening : l10n.listenTapToPlay,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AnimatedSwitcher(
                    duration: AppMotion.medium,
                    child:
                        _captionsOn
                            ? Text(
                              _word.text,
                              key: ValueKey(_word.id),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium,
                            )
                            : const SizedBox(height: 32),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Center(
                    child: AppIconButton(
                      icon: Icons.replay_rounded,
                      filled: true,
                      size: 72,
                      semanticLabel: l10n.choicePlayWord,
                      onPressed: _play,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ToggleChip(
                        icon: Icons.slow_motion_video_rounded,
                        label: l10n.practiceSlowly,
                        active: _slow,
                        onTap: () => setState(() => _slow = !_slow),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _ToggleChip(
                        icon:
                            _captionsOn
                                ? Icons.closed_caption_rounded
                                : Icons.closed_caption_off_rounded,
                        label:
                            _captionsOn
                                ? l10n.listenHideCaptions
                                : l10n.listenShowCaptions,
                        active: _captionsOn,
                        onTap: () => setState(() => _captionsOn = !_captionsOn),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  if (_isLast)
                    AppPrimaryButton(
                      label: l10n.listenContinueToSpeak,
                      icon: Icons.arrow_forward_rounded,
                      onPressed: widget.onComplete,
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: AppOutlineButton(
                            label: l10n.learnPrevious,
                            onPressed:
                                _index == 0 ? null : () => _goTo(_index - 1),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppPrimaryButton(
                            label: l10n.learnNext,
                            onPressed: () => _goTo(_index + 1),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                icon,
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
