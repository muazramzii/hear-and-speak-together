import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// A number that counts up from zero to its target rather than appearing
/// instantly - pairs with `CircularScore` so the ring fills and the digits
/// climb together, making the pronunciation-result reveal feel earned
/// rather than immediate.
class ScoreCountUp extends StatelessWidget {
  const ScoreCountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = AppMotion.celebration,
  });

  final int value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: AppMotion.easeOut,
      builder: (context, animatedValue, _) {
        return Text('$animatedValue', style: style ?? AppTypography.display);
      },
    );
  }
}
