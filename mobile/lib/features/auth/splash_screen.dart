import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shown only while a stored token is being checked at startup.
///
/// The router replaces this as soon as [AuthStatus] resolves, so it is
/// deliberately plain - the goal is to avoid a flash of the sign-in screen for
/// a user who is already signed in.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: const Icon(
                Icons.record_voice_over_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Hear & Speak Together',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            const SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Loading...', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
