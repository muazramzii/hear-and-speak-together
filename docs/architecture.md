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
                 │ PostgreSQL  │    │ Azure AI       │   │ LLM provider  │
                 │             │    │ Speech         │   │ (optional)    │
                 └─────────────┘    └────────────────┘   └───────────────┘
```

The mobile app talks to exactly one system: the Django API. Every external
service is reached server-side. This is a deliberate choice with three
consequences:

1. **Credentials never leave the server.** An API key compiled into a mobile
   binary can be extracted from the APK; a key held in Django cannot.
2. **Cost is controllable.** Rate limits, caching and feature flags live in one
   place rather than being scattered across app versions already installed on
   devices.
3. **Providers can be swapped without shipping an app update.** Replacing the
   feedback provider is a server-side change.

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

**Azure AI Speech** — see below.

---

## Why Azure AI Speech rather than an LLM for scoring

This is the most important decision in the project, so it is worth stating
precisely.

Pronunciation assessment is an **acoustic** problem. It requires comparing the
audio signal a child produced against the expected phonetic realisation of a
reference word. Azure AI Speech Pronunciation Assessment is built for this: it
returns accuracy, fluency, completeness and overall pronunciation scores
derived from the audio itself.

A large language model operates on **text**. Given a transcript, an LLM can
only guess at pronunciation quality from spelling differences — which is not
measurement, it is inference from an already-lossy representation. Two children
whose speech differs audibly can produce the same transcript, and an LLM would
be unable to distinguish them.

Therefore:

- The pronunciation score comes from Azure. Always.
- The LLM, when enabled, only rewrites Azure's structured numbers into warm,
  child-friendly sentences. It never produces or adjusts a score.
- String-similarity measures (edit distance and the like) are **supplementary
  text analysis** only — useful for spotting missing or inserted words, never
  for scoring pronunciation.

If the LLM is unavailable, the app falls back to deterministic score-band
feedback and continues working normally. The application must never depend on
the LLM being reachable.

---

## Service abstractions

Two boundaries keep third-party services from leaking into the rest of the
codebase:

```
Azure Speech  ──>  AzurePronunciationAssessmentService  ──┐
                                                          ├─> PronunciationAssessmentResult ──> business logic ──> PostgreSQL
Mock (tests)  ──>  MockPronunciationAssessmentService  ──┘
```

```
Gemini / OpenAI  ──>  AIService.generateFeedback()  ──>  feedback string
```

Business logic depends on `PronunciationAssessmentResult`, an internal
normalised structure — never on Azure's raw response shape. This means an
Azure API change touches one adapter class rather than the whole application,
and it makes the mock implementations used in testing trivially substitutable.

*(Both abstractions are introduced in Phase 3 and Phase 5 respectively.)*

---

## Bilingual design

The app supports English (`en-US`) and Bahasa Melayu (`ms-MY`).

Two rules govern this:

**Content is authored per language, not translated at runtime.** The Malay
"Haiwan" lesson contains real Malay words — `kucing`, `gajah`, `harimau` — not
machine translations of the English list. Runtime translation would produce
words that are pedagogically wrong for a Malay learner and would give the
speech assessor a reference text nobody actually says.

**Locale capabilities are discovered, not assumed.** Azure's pronunciation
assessment does not expose an identical feature set for every locale;
phoneme-level detail and prosody scoring in particular are locale-dependent.
The backend therefore owns a language configuration layer and reports each
language's capabilities to the client. The Flutter app renders only the metrics
the backend says are available.

The application never fabricates a phoneme or prosody value for a locale that
does not supply one. Where a score is unavailable it is stored as `null` and
simply not displayed.

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
| 4 | Azure pronunciation assessment, the Speak flow, deterministic feedback |
| 5 | Optional LLM feedback layer, Learn / Listen / Quiz modes |
| 6 | Learning analytics, achievements, bottom navigation, lesson browser |
| 7 | Supervisor dashboard, quiz persistence, teacher linking |
| 8 | Share-code UI, production hardening, documentation |

Each phase ended with the full test suite green and a live end-to-end check
against a running server.
