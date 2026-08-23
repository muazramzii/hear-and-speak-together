import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_exception.dart';
import '../../theme/theme.dart';
import '../../models/health_status.dart';
import '../../repositories/health_repository.dart';

/// Phase 1 landing screen: proves the Flutter app can reach Django.
///
/// Every state is communicated visually and in text - the app must never rely
/// on audio or colour alone to convey meaning.
class ConnectionScreen extends ConsumerWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthStatusProvider);

    return Scaffold(
      body: SafeArea(
        // Centred when there is room, scrollable when there is not - short
        // screens and large system font sizes must never clip the status text.
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _AppHeader(),
                  const SizedBox(height: AppSpacing.xl),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: health.when(
                        loading:
                            () => const _StatusBlock(
                              icon: null,
                              title: 'Checking connection...',
                              detail: 'Contacting the Hear & Speak server.',
                              tone: _Tone.neutral,
                            ),
                        error:
                            (error, _) => _StatusBlock(
                              icon: Icons.wifi_off_rounded,
                              title: 'Backend Connection Failed',
                              detail:
                                  error is ApiException
                                      ? error.message
                                      : 'Something went wrong. Please try again.',
                              tone: _Tone.error,
                            ),
                        data: (status) => _resultBlock(status),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed:
                        health.isLoading
                            ? null
                            : () => ref.invalidate(healthStatusProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Check again'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    ApiConstants.baseUrl,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultBlock(HealthStatus status) {
    if (status.isHealthy) {
      return const _StatusBlock(
        icon: Icons.check_circle_rounded,
        title: 'Backend Connected',
        detail: 'The API and the database are both responding.',
        tone: _Tone.success,
      );
    }

    return _StatusBlock(
      icon: Icons.error_outline_rounded,
      title: 'Backend Connection Failed',
      detail:
          status.isDatabaseConnected
              ? status.message
              : 'The API is running but cannot reach the database.',
      tone: _Tone.error,
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
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
        const SizedBox(height: AppSpacing.md),
        Text(
          'Hear & Speak Together',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Listen. Speak. Learn.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

enum _Tone { neutral, success, error }

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({
    required this.icon,
    required this.title,
    required this.detail,
    required this.tone,
  });

  /// When null, a progress indicator is shown in the icon's place.
  final IconData? icon;
  final String title;
  final String detail;
  final _Tone tone;

  Color get _color => switch (tone) {
    _Tone.neutral => AppColors.textSecondary,
    _Tone.success => AppColors.success,
    _Tone.error => AppColors.error,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          width: 48,
          child:
              icon == null
                  ? const CircularProgressIndicator(strokeWidth: 3)
                  : Icon(icon, size: 48, color: _color),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: _color),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
