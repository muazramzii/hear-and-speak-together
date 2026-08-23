import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// An animated waveform - the visual equivalent of "audio is happening",
/// for a child who cannot or should not have to rely on sound alone to
/// know the microphone is live or a word is playing. A row of bars, each
/// animating height on its own phase offset so the motion reads as sound
/// rather than a single mechanical pulse.
///
/// Static (all bars at rest height) whenever [active] is false, so this
/// widget can stay mounted across state changes without needing to be
/// conditionally built.
class AppSoundWave extends StatefulWidget {
  const AppSoundWave({
    super.key,
    required this.active,
    this.color = AppColors.secondary,
    this.barCount = 5,
    this.height = 32,
  });

  final bool active;
  final Color color;
  final int barCount;
  final double height;

  @override
  State<AppSoundWave> createState() => _AppSoundWaveState();
}

class _AppSoundWaveState extends State<AppSoundWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.active ? 'Audio playing' : null,
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.barCount; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  _Bar(
                    height: widget.height,
                    fraction: widget.active ? _fractionFor(i) : 0.2,
                    color: widget.color,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  double _fractionFor(int index) {
    // Each bar rides its own phase of the same loop, so they rise and fall
    // at different moments rather than moving in lockstep.
    final phase = (_controller.value + (index / widget.barCount)) % 1.0;
    return 0.25 + 0.75 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi));
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.height,
    required this.fraction,
    required this.color,
  });

  final double height;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.instant,
      height: height * fraction,
      width: 5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
    );
  }
}
