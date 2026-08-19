# Testing

**358 tests** — 255 backend, 103 Flutter. All run offline, need no API key, and
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

**No automated test may call a paid API.**

A suite that hits Azure or an LLM costs money on every run, needs a key that
cannot be committed, fails without internet, and makes results depend on a
third party's uptime. So both external services sit behind an abstraction with
a mock implementation, selected by configuration:

| Service | Real | Mock | Selected by |
| --- | --- | --- | --- |
| Pronunciation | `AzurePronunciationAssessmentService` | `MockPronunciationAssessmentService` | `SPEECH_PROVIDER` |
| AI feedback | `GeminiAIService` / `OpenAIService` | `MockAIService` | `AI_PROVIDER` |

Both default to the mock, so a fresh checkout runs the full suite immediately.

**The mock tells the truth about locales.** `MockPronunciationAssessmentService`
returns `prosody_score=None` when `enable_prosody=False`, exactly as Azure does
for `ms-MY`. A mock that returned a prosody number for every locale would hide
the very bug the capability layer exists to prevent.

---

## What is covered

### Backend (255)

| Area | Examples |
| --- | --- |
| Health | 200/503 paths, public access, DB reachability |
| Auth | Registration, login, JWT refresh, `/me`, role permissions |
| Content | Language capabilities, per-language filtering, quiz rounds |
| Profiles | Ownership isolation, levelling, streaks |
| Practice | Assessment, feedback bands, evaluation flow, attempt history |
| AI feedback | Every provider failure path |
| Analytics | Weak words, category performance, lesson progress |
| Achievements | Award rules, no double-awarding, bonus points |
| Supervisors | Access filtering, share-code linking, unlinking |

### Flutter (103)

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

**Prosody is never fabricated for Malay.**
```
test_tips_never_mention_a_metric_that_was_not_measured
a Malay result never exposes an intonation score
```
The design mock showed an intonation row on a Malay word. Azure does not
measure it. These tests keep it out.

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
mocks, so CI never spends money or needs an Azure key.

| Job | Steps |
| --- | --- |
| Django | migration-drift check, `manage.py check`, full test suite against a PostgreSQL 18 service container |
| Flutter | `dart format` check, `flutter analyze`, full test suite |

The migration-drift step (`makemigrations --check --dry-run`) fails the build
if a model was changed without a matching migration — a mistake that otherwise
only shows up when someone else pulls and cannot migrate.

---

## Verifying Azure for real

The one thing CI cannot cover, by design. `manage.py check_azure` makes a
single deliberate call and reports what came back — see
[azure-speech.md](azure-speech.md). Its own logic is tested with the service
patched out; the live call is a manual step.

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

- **The real Azure service has never been called.** Everything is verified
  through the mock. `manage.py check_azure` exists to make that first live
  call a deliberate, informative step, but it has only been exercised with the
  service patched out — nobody has yet run it against a real subscription.
- **No microphone hardware test.** Recording is verified through a fake; real
  device capture needs an emulator or phone.
- **No widget tests for the newer screens** — Learn, Listen, Quiz, Progress,
  Rewards, Students. Their controllers and models are tested; their rendering
  is not.
- **No load or performance testing.**

Coverage was not chased as a number. The priority was the paths where being
wrong would be worst: scoring integrity, locale honesty, and access control.
