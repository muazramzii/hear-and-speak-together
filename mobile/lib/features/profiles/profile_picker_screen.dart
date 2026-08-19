import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/learner_profile.dart';
import '../../repositories/profile_repository.dart';
import '../../routes/app_router.dart';
import '../../widgets/app_text_field.dart';

/// "Pilih Profil" - chooses which child is using the app.
///
/// Shown after sign-in on every launch, because on a shared family tablet the
/// previous child is not necessarily the next one.
class ProfilePickerScreen extends ConsumerWidget {
  const ProfilePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profiles = ref.watch(profilesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileChooseTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: profiles.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => _ErrorState(
                    message:
                        error is ApiException
                            ? error.message
                            : l10n.errorGeneric,
                    onRetry: () => ref.invalidate(profilesProvider),
                  ),
              data: (items) => _ProfileList(profiles: items),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileList extends ConsumerWidget {
  const _ProfileList({required this.profiles});

  final List<LearnerProfile> profiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          l10n.profileChooseSubtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),

        if (profiles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              l10n.profileEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),

        for (final (index, profile) in profiles.indexed) ...[
          _ProfileCard(
            profile: profile,
            tint: _tints[index % _tints.length],
            onTap: () {
              ref.read(activeProfileProvider.notifier).state = profile;
              context.goNamed(AppRoutes.homeName);
            },
            onShowCode: () => _showShareCode(context, ref, profile),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _openCreateSheet(context, ref),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.profileAddNew),
        ),
      ],
    );
  }

  static const _tints = [
    AppColors.blueSoft,
    AppColors.pinkSoft,
    AppColors.greenSoft,
    AppColors.amberSoft,
  ];

  Future<void> _showShareCode(
    BuildContext context,
    WidgetRef ref,
    LearnerProfile profile,
  ) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ShareCodeSheet(profile: profile),
    );

    if (changed ?? false) ref.invalidate(profilesProvider);
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateProfileSheet(),
    );

    if (created ?? false) {
      ref.invalidate(profilesProvider);
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.tint,
    required this.onTap,
    required this.onShowCode,
  });

  final LearnerProfile profile;
  final Color tint;
  final VoidCallback onTap;
  final VoidCallback onShowCode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              _AvatarBadge(avatar: profile.avatar),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: AppColors.amber,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          l10n.profileLevel(profile.level),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          '${profile.points}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: profile.levelProgress,
                        backgroundColor: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Behind an explicit tap: the code grants a stranger read
              // access to this child, so it should not sit on screen.
              if (profile.shareCode.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  tooltip: l10n.profileShareCode,
                  onPressed: onShowCode,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the code a family gives to a teacher, and lets them rotate it.
class _ShareCodeSheet extends ConsumerStatefulWidget {
  const _ShareCodeSheet({required this.profile});

  final LearnerProfile profile;

  @override
  ConsumerState<_ShareCodeSheet> createState() => _ShareCodeSheetState();
}

class _ShareCodeSheetState extends ConsumerState<_ShareCodeSheet> {
  late String _code = widget.profile.shareCode;
  bool _busy = false;
  bool _changed = false;

  Future<void> _regenerate() async {
    setState(() => _busy = true);

    try {
      final updated = await ref
          .read(profileRepositoryProvider)
          .regenerateShareCode(widget.profile.id);
      setState(() {
        _code = updated.shareCode;
        _changed = true;
        _busy = false;
      });
    } on ApiException {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.profileShareCode,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.profileShareCodeHelp,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),

          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.violetSoft,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: SelectableText(
              _code,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                // Monospace keeps the characters evenly spaced, which matters
                // when someone is reading them out one at a time.
                fontFamily: 'monospace',
                letterSpacing: 4,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          OutlinedButton.icon(
            onPressed: _busy ? null : _regenerate,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              _busy ? l10n.statusLoading : l10n.profileRegenerateCode,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_changed),
            child: Text(l10n.actionCancel),
          ),
        ],
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.avatar});

  final ProfileAvatar avatar;

  /// Placeholder emoji until the illustration assets are supplied.
  static const _glyphs = {
    ProfileAvatar.boy1: '👦',
    ProfileAvatar.boy2: '🧒',
    ProfileAvatar.girl1: '👧',
    ProfileAvatar.girl2: '👶',
    ProfileAvatar.cat: '🐱',
    ProfileAvatar.elephant: '🐘',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: 56,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Text(
        _glyphs[avatar] ?? '👦',
        style: const TextStyle(fontSize: 28),
      ),
    );
  }
}

class _CreateProfileSheet extends ConsumerStatefulWidget {
  const _CreateProfileSheet();

  @override
  ConsumerState<_CreateProfileSheet> createState() =>
      _CreateProfileSheetState();
}

class _CreateProfileSheetState extends ConsumerState<_CreateProfileSheet> {
  final _name = TextEditingController();
  ProfileAvatar _avatar = ProfileAvatar.boy1;
  String _languageCode = 'en';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(profileRepositoryProvider)
          .createProfile(
            name: _name.text,
            avatar: _avatar,
            languageCode: _languageCode,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      setState(() {
        _busy = false;
        _error = error.errorFor('name') ?? error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.profileCreateTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_error != null) ...[
            AppErrorBanner(message: _error!),
            const SizedBox(height: AppSpacing.md),
          ],

          AppTextField(
            label: l10n.profileNameLabel,
            controller: _name,
            enabled: !_busy,
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            l10n.profileAvatarLabel,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final avatar in ProfileAvatar.values)
                ChoiceChip(
                  label: Text(_AvatarBadge._glyphs[avatar] ?? '?'),
                  selected: _avatar == avatar,
                  onSelected:
                      _busy ? null : (_) => setState(() => _avatar = avatar),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            l10n.settingsPracticeLanguage,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'ms', label: Text('Bahasa Melayu')),
            ],
            selected: {_languageCode},
            showSelectedIcon: false,
            onSelectionChanged:
                _busy
                    ? null
                    : (selection) =>
                        setState(() => _languageCode = selection.first),
          ),
          const SizedBox(height: AppSpacing.xl),

          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? l10n.statusLoading : l10n.actionSave),
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
    );
  }
}
