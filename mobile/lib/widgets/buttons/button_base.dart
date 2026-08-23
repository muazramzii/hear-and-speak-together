import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// A press-scale wrapper shared by every button (and tappable card) in the
/// app, so "pressed" reads the same way everywhere - a small, quick shrink,
/// not a colour change alone. Colour-only feedback is invisible to a child
/// who cannot yet reliably distinguish subtle hue shifts; a size change is
/// not. Public (not button-private) because `AppCard` and its variants use
/// it too.
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.onTap,
    required this.child,
    this.enabled = true,
  });

  final VoidCallback? onTap;
  final Widget child;
  final bool enabled;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: AppMotion.instant,
        curve: AppMotion.easeOut,
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.5,
          child: widget.child,
        ),
      ),
    );
  }
}
