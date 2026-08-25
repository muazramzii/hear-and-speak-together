# Performance (Phase 5)

What changed, and what "60 FPS" actually means for this app given the tools
available to verify it here.

---

## What was fixed

**`AppSoundWave` animated forever, even inactive.** Its `AnimationController`
called `..repeat()` unconditionally in `initState`, so every screen holding
one mounted (Speak's mic button, the Listen/Quiz stages) rebuilt it every
frame regardless of whether audio was actually playing - wasted work on
every frame the state didn't need. It now only repeats while `active: true`
and calls `.stop()` the moment it goes inactive, with no change to what is
rendered (an inactive wave was already drawn at a fixed rest height,
independent of the animation's phase).

**Repaint boundaries around every custom-painted chart.** `CircularScore`
(the Journey's node rings, the Speak result, the Dashboard's pronunciation
ring), the Dashboard's weekly line chart, and `AppSoundWave` now each sit
inside their own `RepaintBoundary`. Without one, Flutter has to consider
repainting the entire subtree an animating widget sits in on every frame;
with one, the animation's repaint is isolated to its own compositor layer
and its parent (a card, a list row) never repaints because of it.

**Illustrations are now cached to disk, not just in memory.** `WordVisual`
used `Image.network`, whose cache lives in Flutter's in-memory `ImageCache`
and is gone the moment the app process ends. It now uses
`CachedNetworkImage`, so a lesson opened once stays fast (and available
offline - see `docs/offline.md`) on every later open, including after the
app is fully closed.

## What was already fine

- **Lazy loading**: every genuinely large or unbounded list already uses a
  builder constructor (`ListView.builder`/`.separated`, `GridView.count`
  with `shrinkWrap`) - checked across the Parent Mode History tab, the
  child Journey path, and the quiz option grids. The Dashboard/Reports
  screens use a plain `ListView(children: [...])` deliberately: the child
  list there is a fixed handful of section cards, not a data-driven feed,
  so a builder would add ceremony with no lazy-loading benefit.
- **Riverpod rebuild scope**: providers are already narrow (one
  `FutureProvider.family` per lesson/profile/filter combination, not one
  large provider watched everywhere), so a change to one child's progress
  does not rebuild another's, or the Students list.

## What "60 FPS" means here, honestly

This environment has no attached Android/iOS device or Flutter
`--profile`-mode DevTools timeline to capture - there was no way to record
an actual frame-time trace here. The changes above are the correct,
well-established fixes for the specific causes of dropped frames Flutter's
own performance guidance names (an animation with no
`RepaintBoundary`, a controller left running with nothing to show for it),
and `flutter analyze`/`flutter test` confirm nothing regressed - but "60
FPS" as a measured, on-device number is not something this pass can claim
to have verified. Before a release, capture a DevTools timeline while
scrolling the Learning Journey and the Parent Progress History tab on a
real mid-range device and confirm no dropped-frame warnings.
