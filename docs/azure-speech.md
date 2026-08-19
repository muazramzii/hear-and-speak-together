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

## The service boundary

```
Azure Speech ──> AzurePronunciationAssessmentService ──┐
                                                        ├──> PronunciationAssessmentResult ──> business logic ──> PostgreSQL
Mock (tests) ──> MockPronunciationAssessmentService ──┘
```

`apps/practice/services/azure_service.py` is the **only** module that imports
the Azure SDK, and it does so lazily inside the method so the native library
never loads during tests. Everything above the boundary works with
`PronunciationAssessmentResult`, our own normalised shape.

This is what makes an Azure API change a one-adapter problem rather than a
whole-application problem, and what makes the mock a genuine drop-in rather
than a special case threaded through the code.

Selection is by `SPEECH_PROVIDER` (`azure` | `mock`), **defaulting to mock**.

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

To try it:

1. Create a Speech resource in the Azure portal.
2. Put the key and region in `backend/.env` (never in `.env.example` — the
   repository is public).
3. Set `SPEECH_PROVIDER=azure`.
4. Practise one word and check the server log.

Expect to verify: the region matches the key, the audio format is accepted, and
`ms-MY` returns `null` prosody as documented. Do this well before any demo.
