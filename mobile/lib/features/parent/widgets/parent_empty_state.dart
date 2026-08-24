import 'package:flutter/material.dart';

import '../design/parent_theme.dart';

/// Friendly, specific empty states - "start your child's first practice",
/// never a bare "no data".
class ParentEmptyState extends StatelessWidget {
  const ParentEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.parentColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 36, color: palette.textSecondary),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
