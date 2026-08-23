import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A one-shot confetti burst for the pronunciation result screen - plays
/// once whenever [active] flips from false to true, then stays finished
/// until the next flip. Built with a plain [CustomPainter] rather than a
/// package: this project has no animation-package dependency today, and a
/// burst of falling rectangles does not need one.
///
/// Reserved for genuinely celebratory moments (a strong score) - see
/// "celebrate progress instead of grading" in the Phase 3 brief. It is not
/// used for every attempt, only ones worth celebrating; overuse would
/// cheapen it for the attempts that actually earn it.
class CelebrationBurst extends StatefulWidget {
  const CelebrationBurst({
    super.key,
    required this.active,
    this.particleCount = 28,
  });

  final bool active;
  final int particleCount;

  @override
  State<CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<_Particle> _particles;

  static const _colors = [
    AppColors.amber,
    AppColors.pink,
    AppColors.blue,
    AppColors.green,
    AppColors.coral,
    AppColors.primary,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _particles = _generateParticles();
    if (widget.active) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(CelebrationBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _particles = _generateParticles();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Particle> _generateParticles() {
    final random = math.Random();
    return List.generate(widget.particleCount, (index) {
      final angle = random.nextDouble() * math.pi - math.pi; // upward fan
      final speed = 0.6 + random.nextDouble() * 0.6;
      return _Particle(
        angle: angle,
        speed: speed,
        color: _colors[random.nextInt(_colors.length)],
        size: 6 + random.nextDouble() * 6,
        spin: (random.nextDouble() - 0.5) * 8,
        startX: random.nextDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ConfettiPainter(
              progress: _controller.value,
              particles: _particles,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.spin,
    required this.startX,
  });

  final double angle;
  final double speed;
  final Color color;
  final double size;
  final double spin;
  final double startX;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress, required this.particles});

  final double progress;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final originX = size.width / 2;
    final originY = size.height * 0.25;
    final fade = (1 - progress).clamp(0.0, 1.0);

    for (final particle in particles) {
      final travel = particle.speed * size.shortestSide * 0.9 * progress;
      final dx =
          originX +
          math.cos(particle.angle) * travel +
          (particle.startX - 0.5) * size.width * 0.3;
      final gravity = 260 * progress * progress;
      final dy = originY - math.sin(particle.angle) * travel * 0.6 + gravity;

      final paint = Paint()..color = particle.color.withValues(alpha: fade);

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(particle.spin * progress);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size * 0.6,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
