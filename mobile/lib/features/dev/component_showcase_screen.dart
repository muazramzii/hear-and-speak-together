import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../widgets/app_widgets.dart';

/// Every reusable design-system widget, in one developer-only screen - not
/// shown to a child, and not linked from anywhere a child could reach. This
/// is the review surface for Phase 3 Stage 1: a way to see every token and
/// component together before any screen is redesigned to use them.
class ComponentShowcaseScreen extends StatefulWidget {
  const ComponentShowcaseScreen({super.key});

  @override
  State<ComponentShowcaseScreen> createState() =>
      _ComponentShowcaseScreenState();
}

class _ComponentShowcaseScreenState extends State<ComponentShowcaseScreen> {
  bool _micListening = false;
  bool _celebrate = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Component Showcase (dev only)')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const _SectionTitle('Colours'),
            const _ColorSwatches(),
            const _SectionTitle('Typography'),
            const _TypographySamples(),
            const _SectionTitle('Spacing & Radius'),
            const _SpacingAndRadiusSamples(),
            const _SectionTitle('Buttons'),
            _ButtonSamples(),
            const _SectionTitle('Circular Microphone Button'),
            _MicButtonSample(
              listening: _micListening,
              onToggle: () => setState(() => _micListening = !_micListening),
            ),
            const _SectionTitle('Cards'),
            const _CardSamples(),
            const _SectionTitle('Progress'),
            const _ProgressSamples(),
            const _SectionTitle('Mascot'),
            const _MascotSamples(),
            const _SectionTitle('Celebration'),
            _CelebrationSample(
              active: _celebrate,
              onTrigger: () => setState(() => _celebrate = true),
              onReset: () => setState(() => _celebrate = false),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
      child: Text(title, style: AppTypography.h2.copyWith(fontSize: 22)),
    );
  }
}

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches();

  static const _swatches = <(String, Color)>[
    ('Primary', AppColors.primary),
    ('Secondary', AppColors.secondary),
    ('Accent', AppColors.accent),
    ('Background', AppColors.background),
    ('Surface', AppColors.surface),
    ('Surface Variant', AppColors.surfaceVariant),
    ('Success', AppColors.success),
    ('Warning', AppColors.warning),
    ('Error', AppColors.error),
    ('Text Primary', AppColors.textPrimary),
    ('Text Secondary', AppColors.textSecondary),
    ('Border', AppColors.border),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final (name, color) in _swatches)
          SizedBox(
            width: 132,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 56,
                  width: 132,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    '${(AppA11y.contrastRatio(Colors.white, color)).toStringAsFixed(1)}:1',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppA11y.textColorFor(color),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(name, style: AppTypography.caption),
              ],
            ),
          ),
      ],
    );
  }
}

class _TypographySamples extends StatelessWidget {
  const _TypographySamples();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Display 56/w800',
          style: AppTypography.display.copyWith(fontSize: 40),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('H1 - 32/w800', style: AppTypography.h1),
        Text('H2 - 26/w800', style: AppTypography.h2),
        Text('H3 - 20/w700', style: AppTypography.h3),
        Text('Body - 16/w600', style: AppTypography.body),
        Text('Caption - 13/w600', style: AppTypography.caption),
      ],
    );
  }
}

class _SpacingAndRadiusSamples extends StatelessWidget {
  const _SpacingAndRadiusSamples();

  static const _spacing = <(String, double)>[
    ('4', AppSpacing.space4),
    ('8', AppSpacing.space8),
    ('12', AppSpacing.space12),
    ('16', AppSpacing.space16),
    ('20', AppSpacing.space20),
    ('24', AppSpacing.space24),
    ('32', AppSpacing.space32),
    ('40', AppSpacing.space40),
  ];

  static const _radii = <(String, double)>[
    ('Small', AppRadius.small),
    ('Medium', AppRadius.medium),
    ('Large', AppRadius.large),
    ('XL', AppRadius.xl),
    ('Full', 32), // AppRadius.full is 999 - capped visually at 32 here
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in _spacing)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(label, style: AppTypography.caption),
                ),
                Container(height: 12, width: value, color: AppColors.primary),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          children: [
            for (final (label, value) in _radii)
              Column(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: AppColors.violetSoft,
                      borderRadius: BorderRadius.circular(value),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(label, style: AppTypography.caption),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _ButtonSamples extends StatefulWidget {
  @override
  State<_ButtonSamples> createState() => _ButtonSamplesState();
}

class _ButtonSamplesState extends State<_ButtonSamples> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.sm,
      children: [
        AppPrimaryButton(label: 'Primary - normal', onPressed: () {}),
        const AppPrimaryButton(label: 'Primary - disabled', onPressed: null),
        AppPrimaryButton(
          label: 'Primary - loading',
          isLoading: _loading,
          onPressed: () async {
            setState(() => _loading = true);
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) setState(() => _loading = false);
          },
        ),
        AppSecondaryButton(label: 'Secondary - normal', onPressed: () {}),
        const AppSecondaryButton(
          label: 'Secondary - disabled',
          onPressed: null,
        ),
        AppOutlineButton(label: 'Outline - normal', onPressed: () {}),
        const AppOutlineButton(label: 'Outline - disabled', onPressed: null),
        Row(
          children: [
            AppIconButton(
              icon: Icons.favorite_rounded,
              onPressed: () {},
              filled: true,
            ),
            const SizedBox(width: AppSpacing.md),
            const AppIconButton(
              icon: Icons.favorite_rounded,
              onPressed: null,
              filled: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _MicButtonSample extends StatelessWidget {
  const _MicButtonSample({required this.listening, required this.onToggle});

  final bool listening;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppMicButton(
          state:
              listening
                  ? AppMicButtonState.listening
                  : AppMicButtonState.normal,
          onPressed: onToggle,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          listening
              ? 'state: listening (tap to stop)'
              : 'state: normal (tap to start)',
          style: AppTypography.caption,
        ),
      ],
    );
  }
}

class _CardSamples extends StatelessWidget {
  const _CardSamples();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.md,
      children: [
        HeroCard(
          child: Text(
            'Hero Card',
            style: AppTypography.h3.copyWith(color: Colors.white),
          ),
        ),
        const LessonCard(title: 'Animals', subtitle: '8 words', progress: 0.6),
        const LessonCard(title: 'Colours', subtitle: '6 words', isLocked: true),
        const LessonCard(
          title: 'Numbers',
          subtitle: '10 words',
          isCompleted: true,
          progress: 1,
        ),
        Row(
          spacing: AppSpacing.md,
          children: const [
            Expanded(
              child: ProgressCard(
                value: '87%',
                label: 'Average Score',
                icon: Icons.insights_rounded,
                tint: AppColors.greenSoft,
                accent: AppColors.successStrong,
              ),
            ),
            Expanded(
              child: AchievementCard(
                emoji: '🏅',
                name: 'First Lesson',
                description: 'Complete a lesson',
                earned: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressSamples extends StatelessWidget {
  const _ProgressSamples();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.lg,
      children: [
        const LinearProgressBar(value: 0.65),
        const XpProgress(value: 0.4, label: '40 / 100 XP'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CircularScore(
              value: 0.87,
              size: 100,
              child: Text('87', style: AppTypography.statNumber),
            ),
            const DailyGoalProgress(value: 0.6, completed: 3, total: 5),
          ],
        ),
      ],
    );
  }
}

class _MascotSamples extends StatelessWidget {
  const _MascotSamples();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      children: [
        for (final state in MascotState.values)
          Column(
            children: [
              Mascot(state: state, size: 72),
              const SizedBox(height: AppSpacing.xs),
              Text(state.name, style: AppTypography.caption),
            ],
          ),
      ],
    );
  }
}

class _CelebrationSample extends StatelessWidget {
  const _CelebrationSample({
    required this.active,
    required this.onTrigger,
    required this.onReset,
  });

  final bool active;
  final VoidCallback onTrigger;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Stack(
        children: [
          Center(
            child: AppOutlineButton(
              label: 'Trigger burst',
              expand: false,
              onPressed: () {
                onReset();
                Future.microtask(onTrigger);
              },
            ),
          ),
          Positioned.fill(child: CelebrationBurst(active: active)),
        ],
      ),
    );
  }
}
