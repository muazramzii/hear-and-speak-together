# Azure AI Speech

How pronunciation is scored, why Azure does it rather than an LLM, and how the
system handles the fact that Azure does not treat every language the same.

---

## Why Azure and not a language model

This is the most important design decision in the project.

Pronunciation assessment is an **acoustic** problem. Judging how a child said a
word requires comparing the audio signal against the expected phonetic
realisation of that word. Azure AI Speech Pronunciation Assessment does exactly
this: it consumes the recording and returns accuracy, fluency, completeness and
an overall pronunciation score derived from the sound itself.

A large language model operates on **text**. Given only a transcript, an LLM
can do no better than guess at pronunciation quality from spelling differences
— which is not measurement, it is inference from an already-lossy
representation. Two children whose speech differs audibly can produce an
identical transcript, and the model would have no way to tell them apart.

So:

- **The score always comes from Azure.** Every number on the result screen
  traces back to a measurement of the audio.
- **The LLM only rewords.** When enabled, it converts numbers Azure already
  produced into warmer phrasing. It never sees audio and never alters a score.
- **String similarity is not scoring.** Edit distance and the like are used, if
  at all, as supplementary text comparison — spotting a missing or inserted
  word — never as a pronunciation score.

A useful way to state it in a report: *the system uses Azure AI Speech
Pronunciation Assessment to evaluate the learner's spoken pronunciation against
a predefined reference word.*

---

## Scripted assessment

Vocabulary practice always knows the target word in advance, so the app uses
**scripted** assessment: the reference text is supplied to Azure up front.

The alternative, unscripted assessment, first transcribes whatever was said and
then scores that. For a single known word this is strictly worse — a
mis-transcription becomes a wrong reference, and the child is scored against a
word nobody asked them to say.

`enable_miscue` is off. Miscue detection compares against a longer script to
find skipped or inserted words; for one word it only adds noise.

---

## Locale capabilities — the part that matters

**Azure does not expose an identical feature set across locales.** Verified
against Microsoft Learn on **2026-08-19**:

| Capability | `en-US` | `ms-MY` |
| --- | --- | --- |
| Pronunciation assessment | ✅ | ✅ (one of 34 supported locales) |
| Accuracy / Fluency / Completeness | ✅ | ✅ |
| **Prosody (intonation, stress, rhythm)** | ✅ | ❌ **en-US only** |
| Phoneme *names* (IPA) | ✅ | ❌ score only, no identity |
| Syllable-level scores | ✅ | ❌ en-US only |

The documentation is explicit: *"Prosody assessment is only available in the
en-US locale."* And on phonemes: *"For other locales, you can only get the
phoneme score."*

### What this means in practice

The project's design mock showed an **"Intonasi baik"** (good intonation) row
on the Malay word *bola*. **That is not implementable.** Azure does not measure
intonation for `ms-MY`, so any such row would be a fabricated measurement
dressed up as a result.

Rather than leave this to be discovered late, the constraint is encoded in
three places:

1. **The database.** `Language` carries `supports_prosody`,
   `supports_phoneme_names` and `supports_syllable_scores`, plus
   `capabilities_verified_on` recording when they were last checked. The Django
   admin warns against enabling a flag Azure does not support.
2. **The service call.** `enable_prosody` is passed from the verified flag, not
   guessed. Prosody assessment is requested only where it exists.
3. **The API and UI.** The practice response carries `available_metrics`, and
   any unmeasured score is `null`. The app renders only what the locale can
   actually measure — a `null` is never displayed as zero.

Tests assert all of this, including that the **mock** service honours the same
rule. A mock that returned prosody for every locale would hide precisely the
bug this layer exists to prevent.

---

## When Azure is not available

Azure requires a subscription, and that is not always obtainable — a student
signup can be rejected, and the standard free tier needs a card. So the project
supports a second real assessor, **SpeechAce**, which offers a free trial tier.

**But no single free provider covers both languages.** SpeechAce supports:

`en-us` · `en-gb` · `fr-fr` · `fr-ca` · `es-es` · `es-mx`

**Malay is not on that list**, and neither ELSA nor any other hosted
pronunciation-scoring API covers it. Azure's `ms-MY` support is genuinely
unusual, which is exactly why it was chosen first.

That is why the provider is selected **per language**, not globally:

| Language | Provider | Why |
| --- | --- | --- |
| `en-US` | SpeechAce (or Azure) | Real acoustic scoring, free trial tier |
| `ms-MY` | Azure, or the mock | SpeechAce cannot score Malay at all |

Set it on each `Language` row in the admin via `assessment_provider`.
`default` defers to the `SPEECH_PROVIDER` setting.

**Sending Malay audio to SpeechAce is refused, not substituted.** Scoring
Malay against an English acoustic model would return a confident, entirely
meaningless number — worse than no score, because it looks real. A test
asserts no HTTP request is even made for an unsupported dialect.

SpeechAce also returns fewer metrics than Azure: no prosody, and its fluency
and completeness describe connected speech rather than single words. All three
are stored as `null` rather than filled with a number that means something
different — the same rule the capability layer applies to Azure's locales.

### Setting it up

1. Get a trial key from [speechace.com](https://www.speechace.com/api-plans/)
   — no card for the trial, but the free tier is a small number of
   assessments per day, so keep `SPEECH_PROVIDER=mock` for development.
2. Put it in `backend/.env` as `SPEECHACE_API_KEY`.
3. In the admin, set the English `Language` row's `assessment_provider` to
   `speechace`, and leave Malay on `mock` (or `azure` if you obtain a key).

---

## The service boundary

```
Azure Speech  ──>  AzurePronunciationAssessmentService  ──┐
SpeechAce     ──>  SpeechAceAssessmentService           ──┼──>  PronunciationAssessmentResult  ──>  business logic  ──>  PostgreSQL
Mock (tests)  ──>  MockPronunciationAssessmentService   ──┘
```

`azure_service.py` is the **only** module that imports the Azure SDK, and it
does so lazily inside the method so the native library never loads during
tests. `speechace_service.py` is the only one that knows SpeechAce's request
shape. Everything above the boundary works with
`PronunciationAssessmentResult`, our own normalised shape.

Adding SpeechAce was the test of this design, and it held: a whole second
provider went in without a single change to the models, the evaluation
service, the feedback engine, the API response, or the app. The abstraction
paid for itself the first time it was needed.

Selection: a `Language` row's `assessment_provider` wins if set; otherwise the
`SPEECH_PROVIDER` setting decides. Both **default to the mock**.

---

## Audio format

The app records **16 kHz, mono, 16-bit PCM WAV**, which is what Azure's speech
models expect. Sending a compressed format risks a worse score for reasons that
have nothing to do with the child's pronunciation.

Recordings are validated before upload — empty and oversized (>5 MB) clips are
rejected client- and server-side — so a bad recording never reaches a paid API.

---

## Error handling

Azure cancellations are classified and translated into child-safe messages. The
technical reason is logged server-side and never returned:

| Azure condition | What the child sees |
| --- | --- |
| Authentication failure | "Speech assessment is not available right now." |
| Quota / throttling | "We are a bit busy right now. Please try again in a moment." |
| Timeout | "That took too long. Please try again." |
| Anything else | "Speech assessment is temporarily unavailable. Please try again." |

**Silence is not an error.** `NoMatch` means the recording held nothing
recognisable — an entirely ordinary thing for a child to do. It still stores an
attempt (useful information for a parent), awards 0 points, and shows "We could
not hear anything."

---

## Text-to-speech

The **listen** button uses on-device TTS (`flutter_tts`), not Azure.

A child taps it repeatedly per word. Routing that through a paid API would
multiply cost for no pedagogical gain and would stop the feature working
offline. Azure's neural voices are configured on the `Language` model
(`en-US-AnaNeural`, a child voice, and `ms-MY-YasminNeural`) for use if
server-side TTS is added later.

Malay TTS is not installed on every Android device, so `WordSpeaker` can report
availability and the UI can hide a button that would do nothing.

---

## Cost control

1. Assessment fires only on a deliberate stop, never from a widget rebuild.
2. Audio is validated before upload.
3. TTS is on-device.
4. `SPEECH_PROVIDER=mock` by default — a fresh checkout costs nothing.
5. No test in either suite calls Azure.
6. `STORE_AUDIO=False` by default.

---

## Before going live

The Azure integration has been built against the documented API and exercised
through the mock. It has **not** been run against a real Azure subscription.

There is a command for exactly this, so the first live call is a deliberate
check rather than a demo that either works or doesn't:

```bash
python manage.py check_azure
```

With no arguments it sends **one second of silence**. Azure should answer *"no
speech recognised"* — and here that is a **success**: reaching that answer
proves the key, the region, the locale and the audio format were all accepted.
Only the recognition failed, deliberately.

```
Configuration
  SPEECH_PROVIDER      azure
  AZURE_SPEECH_KEY     set, ends 'a1b2'
  AZURE_SPEECH_REGION  southeastasia
  locale               en-US

Calling Azure (en-US, reference 'elephant')...
  OK  Azure answered 'no speech recognised', which is exactly right for silence.
  OK  Credentials, region, locale and audio format are all accepted.
```

The key is never printed in full — only the last four characters, enough to
tell two keys apart.

To score real speech, pass a recording:

```bash
python manage.py check_azure --audio recording.wav --word elephant
```

```bash
python manage.py check_azure --locale ms-MY --word bola --audio bola.wav
```

That prints every metric and marks the ones the locale did not measure. It
also **checks the stored capability flag against reality**: if the database
says `ms-MY` has no prosody and Azure returns one anyway (or vice versa), it
says so and tells you to update `Language.supports_prosody` and
`capabilities_verified_on`. The whole capability layer rests on that claim, so
this is where it gets tested for real rather than assumed.

Steps:

1. Create a Speech resource in the Azure portal.
2. Put the key and region in `backend/.env` (never in `.env.example` — the
   repository is public).
3. Run `check_azure`.
4. Set `SPEECH_PROVIDER=azure` once it passes.

Do this well before any demo, not the night before.
