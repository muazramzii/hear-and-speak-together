import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../theme/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/progress.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/progress_repository.dart';

/// "Ganjaran" - the badges a learner has earned, and the ones still ahead.
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(activeProfileProvider);

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.rewardsTitle)),
        body: Center(child: Text(l10n.practiceChooseProfileFirst)),
      );
    }

    final badges = ref.watch(achievementsProvider(profile.id));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.rewardsTitle),
      ),
      body: SafeArea(
        child: badges.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error is ApiException
                            ? error.message
                            : l10n.errorGeneric,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed:
                            () => ref.invalidate(
                              achievementsProvider(profile.id),
                            ),
                        child: Text(l10n.actionTryAgain),
                      ),
                    ],
                  ),
                ),
              ),
          data: (items) => _BadgeList(badges: items),
        ),
      ),
    );
  }
}

class _BadgeList extends StatelessWidget {
  const _BadgeList({required this.badges});

  final List<AchievementBadge> badges;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final earned = badges.where((badge) => badge.earned).toList();
    final locked = badges.where((badge) => !badge.earned).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (earned.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text(
              l10n.rewardsNone,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else ...[
          Text(
            l10n.rewardsEarned,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final badge in earned) _BadgeRow(badge: badge),
          const SizedBox(height: AppSpacing.lg),
        ],

        if (locked.isNotEmpty) ...[
          Text(
            l10n.rewardsLocked,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final badge in locked) _BadgeRow(badge: badge),
        ],
      ],
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.badge});

  final AchievementBadge badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        // State is announced, not conveyed by opacity alone.
        label:
            badge.earned
                ? '${badge.name}, ${context.l10n.rewardsEarned}'
                : '${badge.name}, ${context.l10n.rewardsLocked}',
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: badge.earned ? AppColors.amberSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: badge.earned ? AppColors.amber : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Opacity(
                opacity: badge.earned ? 1 : 0.35,
                child: Text(badge.icon, style: const TextStyle(fontSize: 34)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      badge.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (badge.earned)
                const Icon(Icons.check_circle_rounded, color: AppColors.success)
              else
                const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
