# Phase 3, Stage 1 — design system

The Flutter design system: theme tokens, reusable components, the mascot
placeholder system, and the Component Showcase screen used to review all of
it. This is a **frontend-only** stage - nothing here touches the backend,
the API, navigation architecture, or any database model, and no screen
besides the developer-only showcase has been redesigned yet.

This document replaces an earlier version written for a first pass at this
stage; that pass's `lib/design_system/` package and `lib/core/theme/`
location have been superseded by the structure below, per a more detailed
Stage 1 specification. Nothing in the four screens touched during that first
pass (Home, the lesson picker, Speaking Practice) has changed visually -
this was a relocation and consolidation of the same tokens and components,
not a redesign.

---

## File structure

```
lib/theme/
  colors.dart        AppColors, AppA11y (WCAG contrast helpers)
  typography.dart     AppTypography (Display/H1/H2/H3/Body/Caption + extras), buildTextTheme()
  spacing.dart          AppSpacing (the 8pt scale + t-shirt aliases)
  radius.dart             AppRadius (Small/Medium/Large/XL/Full)
  shadows.dart              AppShadows (small/medium/large/glow)
  motion.dart                 AppMotion (durations + curves)
  theme.dart                   AppGradients, AppTheme (assembles ThemeData) - barrel-exports the rest

lib/widgets/
  app_widgets.dart     barrel - one import for every component below
  buttons/
    button_base.dart    AppPressable (shared press-scale animation)
    primary_button.dart AppPrimaryButton
    secondary_button.dart AppSecondaryButton
    outline_button.dart AppOutlineButton
    icon_button.dart     AppIconButton
    mic_button.dart      AppMicButton, AppMicButtonState
  cards/
    app_card.dart        AppCard (base)
    hero_card.dart        HeroCard
    lesson_card.dart       LessonCard
    progress_card.dart      ProgressCard
    achievement_card.dart    AchievementCard
  progress/
    circular_score.dart  CircularScore
    linear_progress.dart  LinearProgressBar
    xp_progress.dart       XpProgress
    daily_goal_progress.dart DailyGoalProgress
  mascot/
    mascot.dart          Mascot, MascotState, MascotSpeechBubble
    celebration_burst.dart CelebrationBurst

lib/features/dev/component_showcase_screen.dart   ComponentShowcaseScreen
```

Import `theme/theme.dart` for every token (it re-exports colors, typography,
spacing, radius, shadows and motion) and `widgets/app_widgets.dart` for
every component. Screens should never need a more specific import than
those two.

---

## Colour palette

Semantic tokens only - no screen should hold a raw `Color(0x...)`. The
brand mood is deliberately three colours, not a rainbow: soft purple
(primary), sky blue (secondary), warm yellow (accent).

| Token | Value | Role |
| --- | --- | --- |
| `primary` / `primaryDark` | `#7C5CE0` / `#5F42B8` | Soft purple - the brand colour |
| `secondary` / `secondaryDark` | `#5B8DEF` / `#3270EB` | Sky blue |
| `accent` | `#F7C33F` | Warm yellow |
| `background` | `#F8F7FC` | Scaffold background |
| `surface` | `#FFFFFF` | Cards, sheets |
| `surfaceVariant` | `#F3F1FA` | A second, light-violet surface tone for layering one card on another without a border |
| `success` / `warning` / `error` | `#35A85A` / `#E8A020` / `#EF5F5F` | Status |
| `textPrimary` / `textSecondary` | `#1F2233` / `#6D727F` | Text |
| `border` | `#E4E6EF` | Dividers, outlines |

A wider set of "content-mode" accents (`amber`, `blue`, `green`, `coral`,
`pink` - `amber`/`blue` are aliases of `accent`/`secondary`) exists
separately for telling the four learning modes and similar content
groupings apart; they are not part of the core brand mood and are never
used for a plain UI action or status colour.

**Two real, measured accessibility fixes carried over from the first Stage 1
pass**, not just relocated: `textSecondary` was darkened from an original
`#7A7F8C` (3.76-4.01:1 contrast, short of WCAG AA's 4.5:1) to `#6D727F`
(clears 4.5:1 against both `background` and `surface`); and
`successStrong`/`errorStrong`/`secondaryStrong`/a pink "strong" variant exist
because their plain counterparts only clear the *large-text* WCAG threshold
(3:1) with white text on top, not the *normal-text* one (4.5:1). `accent`
and `warning` have no "strong" variant - darkening either enough to carry
white text turns it muddy brown, so dark text (`textOnAccent`) is the only
correct choice on them, always.

`AppA11y` (`theme/colors.dart`) implements the WCAG luminance/contrast
formulas directly, so a new colour pairing can be checked the same way
these were derived, and `AppA11y.textColorFor(background)` picks a
guaranteed-legible text colour for any caller-supplied background.

---

## Typography

Nunito throughout, via `google_fonts`. `AppTypography` exposes the
six-level hierarchy the stage asks for, plus a few extras kept from the
first pass for the already-redesigned screens:

| Style | Size / weight | Use |
| --- | --- | --- |
| `display` | 56 / w800 | A hero number (pronunciation score, XP total) |
| `h1` | 32 / w800 | == Material `headlineLarge` |
| `h2` | 26 / w800 | == Material `headlineMedium` |
| `h3` | 20 / w700 | == Material `titleLarge` |
| `body` | 16 / w600 | == Material `bodyLarge` |
| `caption` | 13 / w600 | A short supporting line - distinct from Material's 12px `labelSmall`, which is for dense chip/tag text |
| `statNumber` | 28 / w800 | A secondary figure next to a `display` number |
| `celebration` | 22 / w800 | A short celebratory line under a hero number |
| `mascotSpeech` | 16 / w700 | The mascot's speech-bubble line |

`AppTypography.buildTextTheme()` produces the full 11-slot Material
`TextTheme` every screen already reads via `Theme.of(context).textTheme` -
unchanged in value from before this refactor.

---

## Spacing & radius

`AppSpacing` is the 8pt scale in full - `space4` through `space40` - plus
the t-shirt aliases (`xs`/`sm`/`md`/`lg`/`xl`) that were already threaded
through every screen before this stage, kept at their exact original pixel
values so relocating the file changed nothing visually.

`AppRadius` is `small` (8) / `medium` (16) / `large` (20) / `xl` (28) /
`full` (999), with `buttonRadius`/`cardRadius`/`chipRadius` aliases for the
same continuity reason.

---

## Elevation

`AppShadows` (`small`/`medium`/`large`/`glow(color)`) are low-opacity,
large-blur, small-offset tints of `textPrimary` - never pure black, which
reads harsher than intended at low opacity. `AppCard` uses `small` by
default (just enough lift to separate from the background); `HeroCard` and
the mic button use `glow` (a colour-matched shadow bleeding from the
surface's own gradient) instead of a neutral one.

---

## Motion

`AppMotion` durations: `instant` (100ms, a button press), `fast` (180ms, the
default UI transition), `medium` (280ms, a card expanding or a lesson
unlocking), `slow` (450ms, the mascot's idle loop or a progress fill),
`celebration` (900ms, the result score reveal). Curves: `easeOut`
(`Curves.easeOutCubic`, the default), `easeInOut`, `emphasized`
(`Curves.easeOutBack`, a little overshoot for buttons/cards landing),
`bouncy` (`Curves.elasticOut`, reserved for genuine celebration moments so
it stays meaningful), `gentle` (the mascot's breathing loop).

---

## Components

**Buttons** - `AppPrimaryButton` (gradient fill, the one hero action per
screen), `AppSecondaryButton` (flat solid fill in `secondaryStrong`, for an
action that matters but shouldn't compete with the primary one),
`AppOutlineButton` (border only, the lowest-emphasis tappable action),
`AppIconButton` (icon-only, always at least `AppSpacing.minTapTarget`), and
`AppMicButton` (the circular hero microphone). All four text buttons share
one press-scale animation (`AppPressable`) instead of Material's ripple, and
support `normal`/`pressed`/`disabled`/`loading` (a spinner replaces the
label; `onPressed` is inert while loading so a slow request can't double-
fire). `AppMicButton` owns its own idle/listening pulse-ring animation
internally via `AppMicButtonState` (`normal`/`listening`/`loading`/
`disabled`), so any screen that uses it gets the same motion for free -
Speaking Practice's hero mic button is now a thin wrapper around it rather
than a separate implementation.

**Cards** - `AppCard` is the shared base (flat tint, soft resting shadow,
borderless - the pre-refactor `CardThemeData` outlined every card in
`AppColors.border`; this leans on shadow and spacing for separation
instead). `HeroCard`, `LessonCard`, `ProgressCard` and `AchievementCard` all
build on it or its visual language, so a lesson tile and an achievement
badge read as the same design system rather than four unrelated widgets.

**Progress** - `CircularScore` (the pronunciation-score ring and any other
circular percentage), `LinearProgressBar` (the pill-shaped base every other
linear indicator builds on), `XpProgress` (a labelled, accent-coloured bar
for streaks/XP), `DailyGoalProgress` (a small ring with a flag icon for
"N of M practised today"). All animate to their target value rather than
snapping.

**Mascot** - see below.

---

## The mascot: a state-driven placeholder, not artwork

Per this stage's explicit instruction, `Mascot` generates **no artwork**.
It is built entirely around `MascotState` (`idle`, `happy`, `celebrate`,
`thinking`, `encourage`): each state maps to a tinted circle, one icon from
the app's single consistent icon family (Material Symbols - the same
family used everywhere else in the app), and an idle-bob amplitude. This is
a deliberate change from the first Stage 1 pass, which used the 🐘 emoji as
the mascot's actual face - emoji are reserved for learning content under
this stage's icon rule (achievement badges, word illustrations), not UI
chrome like a mascot's expression, so that usage no longer fits.

**To swap in real artwork later**: everything placeholder-specific lives in
`Mascot`'s private `_iconFor`/`_tintFor`/`_iconColorFor` methods
(`widgets/mascot/mascot.dart`). Replacing their bodies with an
`Image.asset`/Lottie/Rive lookup keyed on `state` is the only change
needed - every caller passes a `MascotState` and reads nothing else, so no
call site anywhere in the app needs to change when real art arrives.

`MascotSpeechBubble` always renders `textPrimary` text regardless of its
fill colour, so a bubble can never end up low-contrast by accident.
`CelebrationBurst` (a one-shot confetti burst, plain `CustomPainter`, no
package dependency) is reserved for genuinely celebratory moments - shown
in the existing Result screen for scores of 75+, and demonstrated on demand
in the Showcase.

---

## Icons

One family throughout: Material Symbols (`Icons.*`), already the only icon
source used anywhere in the app. Emoji appear only inside learning content
- a word's illustration fallback, a category's icon, an achievement badge's
`emoji` field from seeded content - never as a stand-in for UI chrome. The
mascot rewrite above is the one place this stage had to correct an existing
violation of that rule.

---

## Component Showcase

[`features/dev/component_showcase_screen.dart`](../mobile/lib/features/dev/component_showcase_screen.dart)
- a developer-only screen, not part of the child-facing flow and not linked
from anywhere a child could reach (same convention as the Phase 2
pronunciation sandbox: an always-reachable route plus a `kDebugMode`-gated
entry point on Settings, never compiled into a release build). It renders
every colour swatch (with its live-computed contrast ratio against white),
every typography style, the spacing/radius scale, every button in every
state, the mic button, every card, every progress indicator, all five
mascot states, and an on-demand celebration burst - in one scrollable
screen, so the whole system can be reviewed without touching a single
child-facing screen.

Reach it at `/dev/component-showcase`, or via Settings → "Component
Showcase (dev)" in a debug build.

---

## Quality checks

`flutter analyze`: clean. `flutter test`: 97/97, no regressions. Both the
existing three redesigned screens (Home, the lesson picker, Speaking
Practice/Result) and every other screen in the app were updated to import
from the new `theme/`/`widgets/` locations - a mechanical relocation with
old aliases kept wherever a value's name changed, specifically so this
stage changed zero visual pixels outside of the mascot correction described
above.

---

## What this stage did not do

- **Home was not redesigned further.** Per the brief, this stage stopped at
  the design system and the Showcase.
- **No custom illustration assets** - unchanged from the first pass; this
  project still has no illustration pipeline. The mascot is explicitly a
  placeholder now, designed to be swapped rather than mistaken for final
  art.
- **No live visual screenshot verification in this session** - unchanged
  limitation from the first Stage 1 pass (see git history for that
  session's detailed account of the Browser-pane and browser-automation
  constraints hit at the time). Verification here rests on `flutter
  analyze`, the full `flutter test` suite, and manual review of every
  widget tree. Run `flutter run` and open `/dev/component-showcase`
  yourself to see the actual result before approving the direction.
