# Architecture

This document records the structural decisions behind Hear & Speak Together
and the reasoning that supports them. It is written to be defensible in a
Final Year Project report.

---

## System overview

```
┌──────────────┐   HTTPS / JSON    ┌────────────────────┐
│   Flutter    │ ────────────────> │  Django REST API   │
│  (mobile)    │ <──────────────── │                    │
└──────────────┘                   └─────────┬──────────┘
                                             │
                        ┌────────────────────┼────────────────────┐
                        │                    │                    │
                        v                    v                    v
                 ┌─────────────┐    ┌────────────────┐   ┌───────────────┐
                 │ PostgreSQL  │    │ Whisper        │   │ LLM provider  │
                 │             │    │ (self-hosted,  │   │ (optional)    │
                 │             │    │ in-process)    │   │               │
                 └─────────────┘    └────────────────┘   └───────────────┘
```

The mobile app talks to exactly one system: the Django API. Speech recognition
runs **inside** the Django process itself, not as a separate external service
— there is no paid speech API anywhere in this architecture. This is a
deliberate choice with three consequences:

1. **No credential to leak, for recognition at all.** There is no speech API
   key to compile into a mobile binary or extract from an APK, because there
   is no speech API — Whisper's weights are loaded directly into the Django
   process.
2. **Cost is controllable.** There is no per-request billing for recognition
   or scoring; the only optional paid dependency is the LLM feedback layer,
   which is off by default and never required.
3. **Providers can be swapped without shipping an app update.** Replacing the
   feedback provider, or the recognition model size, is a server-side change.

---

## Why these technologies

**Flutter** — one Dart codebase targets Android and iOS. For a project scoped
to one developer and one academic year, maintaining two native codebases is
not realistic.

**Django + Django REST Framework** — the ORM, admin site, authentication and
migrations are all included. The built-in admin in particular removes the need
to build a content-management UI for lessons and words, which is a substantial
saving.

**PostgreSQL** — a relational database fits the data, which is highly
relational: users have attempts, attempts belong to words, words belong to
lessons, lessons belong to categories. Progress and analytics are aggregate
queries over that structure, which is exactly what SQL is for.

**Self-hosted Whisper plus a custom pronunciation engine** — see
[pronunciation-engine.md](pronunciation-engine.md) for the full design; the
short version follows.

---

## Why recognition and scoring are separate stages, and why an LLM never scores

This is the most important decision in the project, so it is worth stating
precisely.

Recognition (Whisper) and scoring (the pronunciation engine) are two
deliberately separate stages that never share a responsibility. Whisper only
ever answers "what did the model think was said" — it is a transcription
engine, nothing more. The pronunciation engine only ever answers "how well was
it said," working entirely from the reference word, the recognised text, and
Whisper's own confidence signal — never from raw audio.

A large language model operates on **text**. Given only a transcript, an LLM
can only guess at pronunciation quality from spelling differences — which is
not measurement, it is inference from an already-lossy representation. Two
children whose speech differs audibly can produce the same transcript, and an
LLM would be unable to distinguish them.

Therefore:

- The pronunciation score always comes from the deterministic engine, never
  from a model call.
- The LLM, when enabled, only rewrites the engine's structured numbers into
  warm, child-friendly sentences. It never produces or adjusts a score.
- Phonetic-feature distance (via `panphon`), not naive string similarity, is
  what "similarity" measures — plain edit distance over text is never used as
  the pronunciation score.

If the LLM is unavailable, the app falls back to deterministic score-band
feedback and continues working normally. The application must never depend on
the LLM being reachable.

---

## Service abstractions

Two boundaries keep swappable pieces from leaking into the rest of the
codebase:

```
Whisper (real)  ──>  WhisperSpeechRecognitionService  ──┐
                                                        ├─> RecognitionResult ──> PronunciationEngine ──> business logic ──> PostgreSQL
Mock (tests)    ──>  MockSpeechRecognitionService     ──┘
```

```
Gemini / OpenAI  ──>  AIService.generateFeedback()  ──>  feedback string
```

Only recognition is swappable this way — the pronunciation engine downstream
of it is deterministic and identical in every environment, so there is
nothing to select for scoring. Business logic depends on `RecognitionResult`,
an internal normalised structure, never on Whisper's raw segment objects.
This means the recognition implementation can change without touching the
engine, the API response, or the app, and it makes the mock trivially
substitutable in tests.

---

## Bilingual design

The app supports English (`en-US`) and Bahasa Melayu (`ms-MY`).

Two rules govern this:

**Content is authored per language, not translated at runtime.** The Malay
"Haiwan" lesson contains real Malay words — `kucing`, `gajah`, `harimau` — not
machine translations of the English list. Runtime translation would produce
words that are pedagogically wrong for a Malay learner and would give the
speech assessor a reference text nobody actually says.

**No metric is ever fabricated.** There is no prosody, intonation, or
phoneme-identity score anywhere in this architecture, for either language —
Whisper plus a text-level phonetic comparison has no acoustic signal to
derive them from. Rather than fabricate one, or advertise it as unavailable
per locale, the metric simply does not exist here: not a `null` placeholder
for something that might one day be measured, just absent from the model, the
API response, and the UI. Every attempt in both languages carries the same
three metrics — similarity, confidence, completeness — because the engine
measures the same three things regardless of language.

---

## Layering

**Backend.** Views stay thin: they authenticate, validate, delegate, and
serialise. Business logic — assessment orchestration, progress recalculation,
weak-word analysis — lives in service classes. This keeps logic testable
without going through HTTP.

**Mobile.** Widgets never call Dio. The chain is:

```
Widget ──> Riverpod provider ──> Repository ──> Dio ──> API
```

Repositories own all network access and translate transport errors into
`ApiException`, a UI-facing type carrying a message that is always safe to show
a child. `AsyncValue` from Riverpod gives every screen its loading, data and
error states without hand-rolled boolean flags.

---

## Accessibility

The app teaches speech, so it must not *require* hearing to operate. Every
piece of feedback that is spoken or scored is also rendered as text; microphone
state is shown visually (Ready / Listening / Processing / Result) rather than
by sound alone; tap targets are at least 56dp because young children have
imprecise motor control; and colour is never the only carrier of meaning —
success and failure states pair colour with both an icon and a text label.

---

## Learners, accounts and supervisors

A **User** is the login. A **Profile** is the learner. One family account holds
several children, each with independent level, points and streak, and
everything that records learning attaches to the Profile — so a sibling's
practice never lands on the wrong child's record.

Parents own their children's profiles. Teachers, who do not, link via an
unguessable **share code** the family gives them. Linking is deliberately
code-based rather than searchable: a supervisor must never be able to discover
learners they were not given access to.

Access is enforced by **filtering the queryset**, not by a per-object
permission check. Another family's child returns `404`, not `403`, because a
`403` would confirm the profile exists.

---

## Learning analytics

Entirely rule-based — no machine learning, no LLM. The questions being asked
("which words does this child keep getting wrong?") are answered exactly by
aggregating their attempts, and a deterministic answer is one a teacher can
check and a supervisor can defend.

Three judgements worth stating:

- **Weak words need repeated evidence.** One bad attempt is a bad recording,
  not a weakness — so a word is flagged only after two or more attempts
  averaging below the threshold.
- **Words-learned uses the *best* attempt, not the average.** A child who
  struggled and then succeeded has learned the word; averaging would punish
  them for practising.
- **Unscored attempts are excluded from averages.** A silent recording is
  stored (a parent wants to know) but measures nothing, and would drag scores
  down unfairly.

Pronunciation figures stay **speaking-only**: a tap on a picture says nothing
about how a child sounds. Rewards, by contrast, count **any** mode — a child
who only plays quizzes has still practised, and earning nothing for it would
discourage the behaviour the rewards exist to encourage.

---

## Development phases

| Phase | Delivered |
| --- | --- |
| 1 | Django + DRF + PostgreSQL foundation, health endpoint, Flutter shell |
| 2 | Custom email-keyed User, JWT authentication, role permissions |
| 3 | Bilingual content models, learner profiles, localization scaffold |
| 4 | Pronunciation assessment integration, the Speak flow, deterministic feedback |
| 5 | Optional LLM feedback layer, Learn / Listen / Quiz modes |
| 6 | Learning analytics, achievements, bottom navigation, lesson browser |
| 7 | Supervisor dashboard, quiz persistence, teacher linking |
| 8 | Share-code UI, production hardening, documentation |
| 9 | `check_azure` diagnostic command and CI workflow *(superseded — see below)* |
| 10 | Migration from Azure/SpeechAce to a self-hosted Whisper + custom pronunciation engine |

Each phase ended with the full test suite green and a live end-to-end check
against a running server.

Phase 4's original implementation used Azure AI Speech, and Phase 9 later
added a SpeechAce fallback for languages Azure could not cover on a free
tier. Phase 10 replaced both entirely with the self-hosted architecture
described in [pronunciation-engine.md](pronunciation-engine.md), after a
student Azure subscription could not be obtained. No Azure or SpeechAce code,
configuration, or dependency remains in the codebase.
