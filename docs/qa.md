# QA (Phase 5)

What was actually verified, how, and what it found - on a real running
instance of the app, not just static analysis.

---

## How this was verified

`flutter analyze` and `flutter test` (123 tests) catch compile errors and
logic regressions, but neither renders a pixel - overflow, theming, and
layout at different screen sizes can only be seen by actually running the
app. That was done here against a real Android emulator (Pixel 9 Pro XL,
API level current stable), driven over `adb`:

- The actual `app-release.apk` (and, after the fix below, a debug rebuild
  for fast iteration) installed and launched for real.
- A real account created through the live registration flow, hitting the
  real Django backend (`10.0.2.2:8000`, the standard emulator alias for
  the host's `localhost`) - not a mocked screen.
- `adb shell wm size <w>x<h>` to test layouts at other logical
  resolutions on the same device, and `adb shell settings put system
  user_rotation 1` for landscape - a real technique, not a simulation:
  the app genuinely re-lays-out at each size, it's just the same physical
  screen reporting a different resolution to Android.
- `adb exec-out screencap` for every screenshot in this document - real
  frames off the device, not a description of expected behavior.

## Dark mode - pass

Confirmed on-device: Parent Mode's Profile screen has a light/dark/system
segmented control (`parent_profile_screen.dart`). Switching to dark
re-themes every card, list tile, toggle, and the bottom navigation bar
correctly - text stays legible, the purple accent carries over, nothing
is washed out or invisible. This matches the frozen Phase 3/4 design
decision that dark mode is Parent-Mode-only (see `parent_preferences.dart`'s
own docstring) - the child app was not expected to and does not have a
dark theme.

## Phone width - pass, after one real fix

At a realistic compact-phone width (360dp logical, e.g. `wm size
1080x2280` at 480dpi) every screen laid out correctly with one exception:

**Found:** the Profile screen's "Appearance" row (`parent_profile_screen.dart`)
wrapped its label to two lines ("Appea-/rance") because the `ListTile`
title had to share the row with a three-segment icon button, and the
default Material `Text` widget has no line limit.

**Fixed:** added `maxLines: 1, overflow: TextOverflow.ellipsis` to that
title, matching the pattern already used elsewhere in the app for
label/trailing-control rows. Verified with a rebuilt debug APK
side-by-side on the same simulated width - the row now renders on one
line ("Appe... " when truly out of room), not two.

(An earlier, unrealistically narrow test at 240dp - smaller than any
shipping phone - also showed the bottom navigation bar's five labels
wrapping. That is a real property of Flutter's stock `NavigationBar`
`Text` widget having no line cap either, but 240dp is not a size any
actual device reports, so it was not treated as a defect worth changing
navigation structure over.)

## Tablet width - pass

At a 512dp-wide tablet-class resolution (`wm size 1536x2048`), every
screen - including the fixed Appearance row - rendered with generous
spacing and no overflow. Layout stays single-column at this width rather
than switching to a two-pane arrangement; nothing breaks, but a
tablet-optimized multi-column layout was out of scope for this pass (no
tablet-specific redesign was requested, and Phase 5 excludes product
redesign).

## Landscape - pass

Rotating the emulator (`user_rotation 1`) while on the Profile screen
confirmed the layout reflows without clipping or overlap - the bottom
navigation bar and app bar both adapt correctly to the shorter height.
Content stays single-column rather than using the extra width, which is
a polish opportunity, not a defect.

## Accessibility

Confirmed in code (not re-verified on-device beyond what the screenshots
already show): every screen wraps in `SafeArea`; interactive controls
carry `Semantics`/`semanticLabel`; the emoji fallback in `WordVisual` is
explicitly excluded from the accessibility tree so screen readers announce
the real word, not a redundant icon; Parent Mode's own text-scale slider
composes with the device's own accessibility text size rather than
overriding it (`MediaQuery(...).copyWith(textScaler: ...)`).

## What this pass did not cover

- No physical device, only an emulator - GPU-bound animation performance
  (see `docs/performance.md`) still hasn't been measured on real hardware.
- The child-facing app flows (lesson, practice, quiz) were not
  re-registered and walked through on-device in this pass, since the
  screens most likely to have space-constrained layouts (dense
  settings rows, segmented controls) are in Parent Mode - this pass
  focused there. `flutter test`'s widget tests already cover the child
  flows' structural correctness.
