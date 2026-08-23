# Phase 3 design system

The Flutter design system behind the Phase 3 redesign: tokens, components,
the accessibility work behind them, and how the four redesigned screens use
them. This is a **frontend-only** phase - nothing here touches the backend,
the API, or any database model.

---

## Where things live

`AppColors` and `AppSpacing` (the two token classes that predate Phase 3)
stay in [`core/theme/app_theme.dart`](../mobile/lib/core/theme/app_theme.dart)
- every existing screen already imports them from there, and moving them
would mean touching every file in the app for no visual benefit. Everything
new for Phase 3 lives in
[`lib/design_system/`](../mobile/lib/design_system/) instead, built on top
of those existing tokens:

```
lib/design_system/
  tokens.dart               AppRadius, AppMotion, AppTypography, AppGradients, AppA11y
  components/
    buttons.dart             AppPrimaryButton, AppSecondaryButton, AppCircularButton
    cards.dart                AppCard, AppGradientCard
    progress.dart              ProgressRing, XpBar
    mascot.dart                  Mascot, MascotBubble
    celebration.dart              CelebrationBurst
  design_system.dart        barrel export
```

Import `design_system/design_system.dart` for everything new; `AppColors` /
`AppSpacing` still come from `core/theme/app_theme.dart` directly.

---

## Colour palette

The existing brand palette (violet primary, amber/blue/green/coral/pink
accents) is unchanged in hue - Phase 3 is a presentation layer on top of it,
not a rebrand. Two real, measured changes were made to it:

**`AppColors.textSecondary` was darkened**, from `0xFF7A7F8C` to
`0xFF6D727F`. The original measured 3.76:1 against the app's background and
4.01:1 against white - short of WCAG AA's 4.5:1 minimum for normal-size text,
despite looking fine at a glance. This is a global fix: every screen using
`textSecondary` (which is most of them, via `bodyMedium`/`labelSmall`) is now
compliant, not just the four redesigned ones.

**Four "strong" accent variants were added** - `greenStrong`, `coralStrong`,
`pinkStrong`, `blueStrong`. The originals (`green`, `coral`, `pink`, `blue`)
carry white text at only 3.0-3.24:1, which clears WCAG's *large-text*
threshold but not the *normal-text* one (4.5:1) - fine for an icon, not for
a button label or chip text at body size. Each "strong" variant is the same
hue and saturation, darkened in HSL space until white text on top clears
4.5:1 exactly:

| Token | Value | Contrast vs. white |
| --- | --- | --- |
| `greenStrong` | `#2B8748` | 4.50 |
| `coralStrong` | `#E91F1F` | 4.50 |
| `pinkStrong` | `#E2187E` | 4.50 |
| `blueStrong` | `#3270EB` | 4.50 |

**Amber and its `warning` twin are excluded from that treatment
deliberately.** Both fail badly with white text (1.64:1 and 2.22:1), but
darkening either enough to reach 4.5:1 turns it a muddy brown that no longer
reads as "amber" - the darkening required is simply too large. Dark text
(`AppColors.textPrimary`) is the only correct choice on amber, always, and
already clears AA comfortably (9.6:1). There is a `textOnAmber` constant
(= `textPrimary`) so this rule has a name to reach for instead of a fresh
"white or dark?" judgement call each time.

---

## Typography

Nunito, unchanged - it was already the app's typeface via `google_fonts`
before Phase 3 (`AppTheme._textTheme` in `app_theme.dart`). `AppTypography`
adds the sizes that scale didn't have: `display` (56px/w800, the
pronunciation-result hero number), `statNumber` (28px/w800), `celebration`
(22px/w800, a short encouraging line), and `mascotSpeech` (16px/w700, always
paired with `textPrimary` regardless of bubble colour).

---

## Spacing, radius, motion

`AppSpacing` (existing) is untouched. `AppRadius` is new and adds two steps
the old scale didn't have (`xs`=8, `xl`=28) around the existing values
(`sm`=12 ≈ old `chipRadius`'s corner case, `md`=16 = `buttonRadius`, `lg`=20 =
`cardRadius`, `pill`=999 = `chipRadius`).

`AppMotion` names five durations (`instant` 100ms through `celebration`
900ms) and four curves (`standard`, `emphasized`, `bouncy`, `gentle`), so
every animated widget in the redesign picks from the same small set instead
of inventing a new number. `bouncy` (`Curves.elasticOut`) is reserved for
genuinely celebratory moments - the result score reveal - so it stays
meaningful rather than becoming the default spring on everything.

---

## Components

**`AppPrimaryButton` / `AppSecondaryButton`** replace `FilledButton` /
`OutlinedButton` on the four redesigned screens (existing screens keep using
Material's buttons via the app `ThemeData` - untouched). Both share a
press-scale animation (`_PressableScale`, shrink to 96% on tap) instead of
Material's ripple, and `AppPrimaryButton` picks its label colour
automatically via `AppA11y.textColorFor` against its gradient's darkest stop,
so a future palette change cannot silently drop a button's contrast below
AA.

**`AppCircularButton`** is the base for the Speaking Practice hero
microphone specifically - not a general-purpose icon button. The pulsing
ring animation around it is built where it's used
(`_HeroMicButton`/`_PulseRing` in `practice_screen.dart`), not baked into the
component, since nothing else needs a "listening" pulse state.

**`AppCard` / `AppGradientCard`** are flat-tint and gradient rounded
surfaces respectively, both borderless (the pre-Phase-3 `CardThemeData`
outlines every card in `AppColors.border` - the redesign leans on colour and
spacing for separation instead). `AppGradientCard` picks its own text/icon
colour the same way `AppPrimaryButton` does.

**`ProgressRing` / `XpBar`** are the circular and linear progress widgets -
both animate to their target value (`TweenAnimationBuilder`) rather than
snapping, and both take their content/colour from the caller rather than
being hardcoded to a percentage label, so the same `ProgressRing` serves the
pronunciation score, a lesson's completion ring, and (with a different
child) nothing at all.

**`CelebrationBurst`** is a one-shot confetti burst, built with a plain
`CustomPainter` rather than a package dependency - this project has no
animation-package dependency today, and a burst of ~28 falling rectangles
does not need one. It plays once whenever its `active` flag flips to `true`
and is reserved for scores of 75+ on the result screen; it is deliberately
not shown for every attempt, so it stays meaningful for the ones that earn
it, in keeping with "celebrate progress instead of grading."

---

## The mascot

**"Ellie" is built from emoji and motion, not a custom illustration asset.**
This project has no illustration pipeline, and hand-drawn character art is
out of scope for what can be produced and verified inside this phase -
stated plainly here rather than presented as more than it is. 🐘 was chosen
because it is already the app's elephant: "elephant"/"gajah" is seeded
vocabulary in both languages, and the emoji already appeared on Home's old
streak card before this redesign.

`Mascot` carries five moods (`idle`, `encouraging`, `happy`, `excited`,
`thinking`), each with a different idle-bob amplitude and, for `happy`/
`excited`, a small sparkle/confetti accessory emoji layered on top via
`Stack` (there is no "elephant with sparkles" emoji, so the sparkle is
composited separately). `MascotBubble` always renders `textPrimary` text
regardless of its fill colour, so a bubble can never end up low-contrast by
accident.

**On the result screen, the mascot's mood follows the score band but its
tone never turns negative** - even the lowest band gets `encouraging`, never
a disappointed or sad expression. This mirrors the backend's own
deterministic feedback bands (`services/feedback.py`), which are
encouraging at every level ("Let's practice together. You can do it!" is
the *lowest* band's message, not a scolding one) - the redesign carries that
tone through visually rather than undermining it with a sad mascot face.

---

## Accessibility

`AppA11y` (in `tokens.dart`) implements the WCAG relative-luminance and
contrast-ratio formulas directly - `relativeLuminance(Color)`,
`contrastRatio(Color, Color)` - rather than relying on a hardcoded table, so
a *new* colour pairing introduced later can be checked programmatically the
same way `textSecondary` and the "strong" accents were derived for this
phase (see "Colour palette" above for the worked numbers).
`AppA11y.textColorFor(background)` picks whichever of white or
`textPrimary` clears the pairing better, and every component that renders on
a caller-supplied colour (`AppPrimaryButton`, `AppGradientCard`,
`AppCircularButton`, the mode-grid icon badges) calls it rather than
hardcoding white.

Beyond colour:

- Every animated state change (button press, mic pulse, score reveal) is
  paired with a text change already present from before Phase 3 - the
  project's existing rule that "state must never be conveyed by sound or
  motion alone" (see `practice_screen.dart`'s `_StageIndicator`) is
  unchanged and still enforced.
- Locked lesson nodes on the Learning Journey carry a `Semantics` label
  explaining *why* they're locked (`journeyLockedHint`), not just that they
  are.
- `AppSpacing.minTapTarget` (56dp, already above Material's 48dp minimum)
  is unchanged and still respected by every new interactive component.

---

## The four redesigned screens

**Home** ([`home_screen.dart`](../mobile/lib/features/home/home_screen.dart)) -
a gradient hero card (`AppGradientCard` + `Mascot` + `XpBar`) replaces the
old flat `_StreakCard`, which also fixes a real pre-existing bug: it printed
hardcoded English strings ("Keep up the great work!", "Ready to start?",
"Practise today to start a streak.") instead of the matching `l10n` getters
that already existed for them (`homeKeepGoing`, `homeReadyToStart`,
`homeStartStreak`) - a Malay learner was silently seeing English text on
that one card. It's fixed now as part of rebuilding the card, not as a
separate change. A new `AppPrimaryButton` ("Continue Learning") leads into
the Journey; the four-mode grid keeps its exact functionality, restyled with
gradient icon badges.

**Learning Journey**
([`lesson_list_screen.dart`](../mobile/lib/features/lessons/lesson_list_screen.dart)) -
the lesson picker (`LessonListScreen` / `LearnLessonListScreen`), turned from
a plain vertical list into a winding path of circular nodes, each showing a
`ProgressRing` for that lesson's completion and a lock icon where
applicable. Lock state is computed **client-side from data that already
exists** - no backend change: a lesson is locked only if the previous one is
incomplete *and* this one has never been opened, so nothing reachable before
this redesign becomes unreachable now. The mascot stands next to whichever
lesson is "next" with an encouraging prompt.

**Speaking Practice** ([`practice_screen.dart`](../mobile/lib/features/practice/practice_screen.dart))
- the hero interaction the brief calls for: a 132dp gradient microphone
button with a "breathing" pulse ring at idle and a faster, larger pulse
while listening (`_HeroMicButton`/`_PulseRing`), so the recording state
reads clearly even without sound. The word card became an `AppGradientCard`
with the illustration in a white circular frame. Every stage still
announces itself in text exactly as before (`_StageIndicator` is otherwise
unchanged) - the animation is additive, not a replacement for the
accessible state announcement that already existed.

**Pronunciation Result** (the same screen's result state, kept in place per
the agreed direction rather than extracted into its own route) - the old
`ScoreGauge` widget is replaced by the shared `ProgressRing`, colour-coded by
band (green/blue/amber/violet - **never red**, so a low score never reads as
a "failure" colour). The mascot's mood follows the same bands, and its
speech bubble shows the backend's own localised feedback sentence directly
(`result.feedback`) - no new strings were needed for this screen at all. A
`CelebrationBurst` plays once for scores of 75+. The similarity/confidence/
completeness breakdown now renders as three small `XpBar`s instead of plain
text rows.

`score_gauge.dart` (the old gauge widget) was deleted - `ProgressRing`
supersedes it and nothing else referenced it.

---

## New localisation keys

Six new keys, added to both `app_en.arb` and `app_ms.arb` with real Malay
translations (not machine-translated placeholders): `homeContinueLearning`,
`journeyTitle`, `journeyMascotPrompt`, `journeyLocked`, `journeyLockedHint`,
`journeyCompleted`. Everything else reuses existing keys - the Speaking
Practice screen in particular needed zero new copy, since the mascot's
speech on the result screen reuses the backend's own already-localised
feedback text rather than introducing parallel English-only mascot lines.

---

## What this phase did not do (and why)

- **No custom illustration assets.** Stated above under "The mascot" - this
  project has no illustration pipeline. Large emoji, gradients, and motion
  carry the "visual-first" requirement instead of hand-drawn art.
- **No live visual screenshot verification of the four redesigned screens in
  this session.** The in-app Browser pane could not composite frames for a
  screenshot (`the Browser pane is not displayed`). A second attempt via a
  separate real-Chrome browser integration did get one genuine screenshot -
  the (unmodified) login screen, rendering correctly with the right font,
  colours and layout, confirming the Flutter web build itself runs
  correctly end to end against the live backend - but automated typing into
  the login form was unreliable in that environment (text events were not
  reaching the field's editing buffer, and the browser window kept resizing
  between calls), so I could not get signed in to reach Home, the Journey,
  Speaking Practice or the Result screen for a real look. Correctness was
  verified through `flutter analyze` (clean) and the full `flutter test`
  suite (97/97, no regressions) instead - but nobody has *looked* at these
  four screens rendered yet. Run `flutter run` (see `docs/development.md`)
  yourself to see the actual result before treating the direction as
  approved - that review is what this stop-and-approve checkpoint is for.
- **Nothing beyond these four screens.** Per the brief, Learn/Listen/Quiz
  round screens, Progress, Rewards, Settings, auth and profile screens are
  all untouched and still use the pre-Phase-3 Material theme directly.
