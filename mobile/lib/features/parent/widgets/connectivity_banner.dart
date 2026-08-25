import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/connectivity_provider.dart';
import '../design/parent_theme.dart';

/// "You're offline - showing saved data." Shown only while actually
/// offline; collapses to nothing the moment connectivity returns, rather
/// than needing to be dismissed.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;
    final palette = context.parentColors;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child:
          isOnline
              ? const SizedBox.shrink()
              : Container(
                key: const ValueKey('offline'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: palette.amberSoft,
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 16,
                      color: palette.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "You're offline - showing saved data.",
                        style: TextStyle(
                          color: palette.amber,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
