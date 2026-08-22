# Testing

**333 tests** — 236 backend, 97 Flutter. All run offline, need no API key, and
cost nothing.

```bash
cd backend && .venv\Scripts\python.exe manage.py test
```

```bash
cd mobile && flutter test
```

```bash
cd mobile && flutter analyze
```

---

## The rule that shapes everything

**No automated test may call a paid API, or load a real speech model.**

A suite that hits an LLM costs money on every run and needs a key that cannot
be committed; a suite that loads a real Whisper model is slow and can trigger
a multi-hour first-run download. So both sit behind an abstraction with a
mock implementation, selected by configuration:

| Service | Real | Mock | Selected by |
| --- | --- | --- | --- |
| Speech recognition | `WhisperSpeechRecognitionService` | `MockSpeechRecognitionService` | `SPEECH_PROVIDER` |
| AI feedback | `GeminiAIService` / `OpenAIService` | `MockAIService` | `AI_PROVIDER` |

Both default to the mock, so a fresh checkout runs the full suite immediately.
The pronunciation engine downstream of recognition is **never** mocked — it
is deterministic Python with no external dependency, so the real engine runs
in every test, exercising the same code path production uses.

**There is nothing per-locale for a mock to get wrong.** Every attempt in
both languages carries the same three metrics — similarity, confidence,
completeness — because the engine measures the same three things regardless
of language. A dedicated test (`test_no_score_is_ever_fabricated_as_prosody`)
asserts no prosody-shaped field exists on the engine's result at all.

---

## What is covered

### Backend (236)

| Area | Examples |
| --- | --- |
| Health | 200/503 paths, public access, DB reachability |
| Auth | Registration, login, JWT refresh, `/me`, role permissions |
| Content | Per-language filtering, quiz rounds |
| Profiles | Ownership isolation, levelling, streaks |
| Recognition | Mock service behaviour, silence handling, factory selection |
| Pronunciation engine | Scoring formula, error classification against the project's own worked examples, configurable weights, completeness capping |
| Practice | Evaluation flow, feedback bands, attempt history |
| AI feedback | Every provider failure path |
| Analytics | Weak words, category performance, lesson progress |
| Achievements | Award rules, no double-awarding, bonus points |
| Supervisors | Access filtering, share-code linking, unlinking |

### Flutter (97)

Auth controller and login screen, API error translation, content and progress
models, practice state machine, quiz session controller, word visuals, and
localization.

---

## Tests worth reading

Some assert things that are easy to get wrong and expensive to discover late.

**Malay content is authored, not translated.**
```
test_malay_content_is_authored_not_translated
```
Asserts `kucing` and `gajah` are present and `cat` and `elephant` are absent.
Would fail immediately if anyone swapped in runtime translation.

**No score is ever fabricated as prosody.**
```
test_no_score_is_ever_fabricated_as_prosody
```
The design mock once showed an intonation row on a Malay word. Nothing in
this pipeline has an acoustic signal to measure intonation from, for either
language, so the field does not exist on the engine's result at all — this
test keeps it that way.

**Errors are only reported when the alignment actually supports them.**
```
test_a_dropped_final_sound_is_a_missing_ending
test_a_wrong_consonant_is_penalised_and_classified
```
Run against the project's own worked examples (`bola`→`bota`, `gajah`→`gaja`)
to prove the phoneme-alignment error detector classifies real, specific
mistakes rather than a generic "wrong" flag.

**The LLM cannot influence the score.**
```
test_the_score_is_untouched_by_the_ai_layer
```
Runs the same attempt with AI on and off and asserts the score and points are
identical.

**The app survives its optional dependencies failing.**
```
test_an_ai_provider_that_raises_cannot_break_an_attempt
```
A provider that throws `RuntimeError` still yields a scored attempt with
deterministic feedback.

**Paid calls only happen deliberately.**
```
evaluating without recording first does nothing
a second stop does not submit twice
```
Guards against a stray rebuild triggering an assessment.

**Weak words need repeated evidence.**
```
test_weak_words_need_repeated_evidence
```
One bad attempt is a bad recording, not a weakness.

**Every word can be told apart in a quiz.**
```
test_every_seeded_word_has_a_visual
test_options_in_one_round_are_visually_distinct
four options render four different visuals
```
Listen hides the word and shows four pictures. Before the `emoji` field
existed, every tile fell back to the same placeholder and the mode was
unanswerable. These guard against that returning.

**Another family's child is unreachable.**
```
test_another_familys_child_is_not_reachable_by_id
```
Returns `404`, not `403` — a `403` would confirm the profile exists.

**Translations are complete.**
```
every English string has a Malay translation
no Malay value is left as the English text
```
Parses both ARB files. An untranslated key would fall back to English
mid-screen, which these catch. Strings the design keeps in English are
allow-listed explicitly.

---

## Continuous integration

`.github/workflows/tests.yml` runs both suites on every push and pull request.
It needs **no secrets**: `SPEECH_PROVIDER` and `AI_PROVIDER` default to their
mocks, so CI never spends money and never loads a real Whisper model.

| Job | Steps |
| --- | --- |
| Django | NLTK data fetch (cached), migration-drift check, `manage.py check`, full test suite against a PostgreSQL 18 service container |
| Flutter | `dart format` check, `flutter analyze`, full test suite |

CI does fetch one thing over the network even with the recognition mock in
use: NLTK's `averaged_perceptron_tagger_eng` and `cmudict` resources, which
the pronunciation engine's real English G2P step needs on every run (the
engine itself is never mocked — see above). That download is not a paid API
and is cached between runs by `actions/cache`.

The migration-drift step (`makemigrations --check --dry-run`) fails the build
if a model was changed without a matching migration — a mistake that otherwise
only shows up when someone else pulls and cannot migrate.

---

## End-to-end scripts

Each phase was also verified against a running server with a script under
`scratchpad/`, exercising the real HTTP surface: auth (18 checks), content and
profiles (28), practice (23), progress (23), supervisor flows (20).

These are development aids, not part of the automated suite — they need a live
server and a seeded database.

---

## What is not covered

Stated plainly, because a test report that overclaims is worse than none.

- **The real Whisper model is verified manually, not by the automated suite.**
  Loading the model and transcribing real audio was exercised directly during
  development (see [pronunciation-engine.md](pronunciation-engine.md) for the
  measured numbers), but the automated suite only ever runs against the mock
  recognition service — by design, so CI stays fast and offline.
- **No microphone hardware test.** Recording is verified through a fake; real
  device capture needs an emulator or phone.
- **No widget tests for the newer screens** — Learn, Listen, Quiz, Progress,
  Rewards, Students. Their controllers and models are tested; their rendering
  is not.
- **No load or performance testing.**

Coverage was not chased as a number. The priority was the paths where being
wrong would be worst: scoring integrity, locale honesty, and access control.
