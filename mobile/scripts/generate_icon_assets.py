"""Generates the app's icon and splash source images.

Draws everything with Pillow's basic primitives rather than importing
external artwork - there is no illustration pipeline in this project (see
lib/widgets/mascot/mascot.dart's docstring), and the same "flat colour,
sound-wave motif" language already used by AppSoundWave/AppGradients in the
Flutter design system is reused here, so the icon reads as *this app's*
icon rather than a generic placeholder.

Run once, locally, whenever the mark needs regenerating:
    python scripts/generate_icon_assets.py

Output goes to assets/icon/, which flutter_launcher_icons and
flutter_native_splash then read (see pubspec.yaml).
"""

from PIL import Image, ImageDraw

# Exact values from lib/theme/colors.dart - the icon must be built from the
# app's own palette, not an invented one.
PRIMARY = (0x7C, 0x5C, 0xE0, 255)
PRIMARY_DARK = (0x5F, 0x42, 0xB8, 255)
WHITE = (255, 255, 255, 255)

SIZE = 1024
SUPERSAMPLE = 4  # draw at 4x and downsample for anti-aliased edges


def _canvas(size):
    return Image.new("RGBA", (size * SUPERSAMPLE, size * SUPERSAMPLE), (0, 0, 0, 0))


def _finish(canvas, size):
    return canvas.resize((size, size), Image.LANCZOS)


def _draw_wave_bubble(draw, s, scale=1.0, color=WHITE, bar_color=None):
    """A rounded speech bubble with a small sound-wave inside it - the same
    "hearing + speaking" idea AppSoundWave already represents in-app, drawn
    once here as the app's mark."""
    cx, cy = s // 2, s // 2
    bubble_w = int(s * 0.62 * scale)
    bubble_h = int(s * 0.46 * scale)
    left = cx - bubble_w // 2
    top = cy - bubble_h // 2 - int(s * 0.03 * scale)
    right = left + bubble_w
    bottom = top + bubble_h
    radius = int(bubble_h * 0.42)

    draw.rounded_rectangle(
        [left, top, right, bottom], radius=radius, fill=color
    )

    # The tail, pointing down-left, like a speech bubble.
    tail_w = int(bubble_w * 0.16)
    tail_x = left + int(bubble_w * 0.22)
    draw.polygon(
        [
            (tail_x, bottom - 2),
            (tail_x + tail_w, bottom - 2),
            (tail_x, bottom + int(bubble_h * 0.30)),
        ],
        fill=color,
    )

    # Sound-wave bars inside the bubble, phase-varied heights - mirrors
    # AppSoundWave's five-bar silhouette.
    bar_color = bar_color or PRIMARY
    n_bars = 5
    bar_w = int(bubble_w * 0.075)
    gap = int(bubble_w * 0.045)
    total_w = n_bars * bar_w + (n_bars - 1) * gap
    start_x = cx - total_w // 2
    heights_fraction = [0.35, 0.65, 1.0, 0.65, 0.35]
    max_bar_h = int(bubble_h * 0.5)

    for i, frac in enumerate(heights_fraction):
        bar_h = int(max_bar_h * frac)
        x0 = start_x + i * (bar_w + gap)
        y0 = cy - int(s * 0.03 * scale) - bar_h // 2
        y1 = y0 + bar_h
        draw.rounded_rectangle(
            [x0, y0, x0 + bar_w, y1], radius=bar_w // 2, fill=bar_color
        )


def make_app_icon():
    """Full-bleed icon: flat primary-purple square, white bubble+wave mark -
    used directly for iOS and as the Android legacy (non-adaptive) icon."""
    s = SIZE * SUPERSAMPLE
    canvas = _canvas(SIZE)
    draw = ImageDraw.Draw(canvas)
    draw.rectangle([0, 0, s, s], fill=PRIMARY)
    _draw_wave_bubble(draw, s, scale=1.0, color=WHITE, bar_color=PRIMARY)
    _finish(canvas, SIZE).convert("RGB").save("assets/icon/app_icon.png")


def make_adaptive_foreground():
    """Android adaptive icon foreground: transparent background, the mark
    scaled down and centred within the ~66% safe zone so it isn't clipped
    by the launcher's mask (circle, squircle, rounded square, ...)."""
    s = SIZE * SUPERSAMPLE
    canvas = _canvas(SIZE)
    draw = ImageDraw.Draw(canvas)
    _draw_wave_bubble(draw, s, scale=0.62, color=WHITE, bar_color=PRIMARY)
    _finish(canvas, SIZE).save("assets/icon/app_icon_foreground.png")


def make_splash_logo():
    """The mark alone, transparent background, for flutter_native_splash -
    it composites this over the splash background colour itself."""
    s = SIZE * SUPERSAMPLE
    canvas = _canvas(SIZE)
    draw = ImageDraw.Draw(canvas)
    _draw_wave_bubble(draw, s, scale=0.9, color=PRIMARY, bar_color=WHITE)
    _finish(canvas, SIZE).save("assets/icon/splash_logo.png")


if __name__ == "__main__":
    make_app_icon()
    make_adaptive_foreground()
    make_splash_logo()
    print("Wrote assets/icon/app_icon.png")
    print("Wrote assets/icon/app_icon_foreground.png")
    print("Wrote assets/icon/splash_logo.png")
