import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'button_base.dart';

/// The four states the hero microphone button can be in. Named after what
/// the *button* is doing, not the screen's broader flow, so this widget
/// stays reusable outside the Speaking Practice screen it was designed for.
enum AppMicButtonState {
  /// Waiting for a tap. A slow, gentle pulse invites the tap without
  /// demanding it.
  normal,

  /// Recording. A fast, large pulse makes the live state readable even
  /// without sound - this app's users may not be able to rely on audio
  /// feedback at all.
  listening,

  /// Busy (e.g. awaiting a scoring result). Not tappable; shows a spinner
  /// instead of pulsing, since nothing is being invited right now.
  loading,

  /// Not tappable and not expecting to become tappable soon (e.g. no
  /// profile chosen yet). No animation - a static, dimmed button reads as
  /// "nothing to do here" more clearly than a paused pulse would.
  disabled,
}

/// The circular hero microphone button - the single biggest, most important
/// tap target on the Speaking Practice screen, but built as a
/// screen-agnostic reusable component. Owns its own idle/listening pulse
/// animation so every screen that uses it gets the same motion for free.
class AppMicButton extends StatefulWidget {
  const AppMicButton({
    super.key,
    required this.state,
    required this.onPressed,
    this.diameter = 132,
    this.normalSemanticLabel = 'Start recording',
    this.listeningSemanticLabel = 'Stop recording',
  });

  final AppMicButtonState state;
  final VoidCallback? onPressed;
  final double diameter;
  final String normalSemanticLabel;
  final String listeningSemanticLabel;

  @override
  State<AppMicButton> createState() => _AppMicButtonState();
}

class _AppMicButtonState extends State<AppMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Gradient get _gradient => switch (widget.state) {
    AppMicButtonState.normal => AppGradients.primary,
    AppMicButtonState.listening => AppGradients.warm,
    AppMicButtonState.loading => AppGradients.secondary,
    AppMicButtonState.disabled => const LinearGradient(
      colors: [AppColors.border, AppColors.border],
    ),
  };

  IconData get _icon => switch (widget.state) {
    AppMicButtonState.listening => Icons.stop_rounded,
    _ => Icons.mic_rounded,
  };

  bool get _pulsing =>
      widget.state == AppMicButtonState.normal ||
      widget.state == AppMicButtonState.listening;

  @override
  Widget build(BuildContext context) {
    final enabled =
        widget.state == AppMicButtonState.normal ||
        widget.state == AppMicButtonState.listening;
    final semanticLabel =
        widget.state == AppMicButtonState.listening
            ? widget.listeningSemanticLabel
            : widget.normalSemanticLabel;
    final gradient = _gradient;
    final iconColor = AppA11y.textColorFor(gradient.colors.last);

    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: enabled,
      child: SizedBox(
        height: widget.diameter * 1.4,
        width: widget.diameter * 1.4,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                if (_pulsing)
                  for (final ringDelay in [0.0, 0.5])
                    _PulseRing(
                      progress: (_pulse.value + ringDelay) % 1.0,
                      color: gradient.colors.last,
                      diameter: widget.diameter,
                      active: widget.state == AppMicButtonState.listening,
                    ),
                child!,
              ],
            );
          },
          child: AppPressable(
            onTap: enabled ? widget.onPressed : null,
            enabled: enabled,
            child: Container(
              height: widget.diameter,
              width: widget.diameter,
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
                boxShadow:
                    enabled
                        ? AppShadows.glow(gradient.colors.last, alpha: 0.4)
                        : null,
              ),
              child:
                  widget.state == AppMicButtonState.loading
                      ? Center(
                        child: SizedBox(
                          height: widget.diameter * 0.3,
                          width: widget.diameter * 0.3,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: iconColor,
                          ),
                        ),
                      )
                      : Icon(
                        _icon,
                        color: iconColor,
                        size: widget.diameter * 0.42,
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({
    required this.progress,
    required this.color,
    required this.diameter,
    required this.active,
  });

  final double progress;
  final Color color;
  final double diameter;

  /// Listening breathes hard enough to read as "this is live" even to a
  /// child not looking directly at it; idle still breathes gently so the
  /// button never looks static.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final maxScale = active ? 1.6 : 1.15;
    final scale = 1.0 + (maxScale - 1.0) * progress;
    final opacity = (1 - progress) * (active ? 0.5 : 0.25);

    return Transform.scale(
      scale: scale,
      child: Container(
        height: diameter,
        width: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: opacity), width: 4),
        ),
      ),
    );
  }
}
