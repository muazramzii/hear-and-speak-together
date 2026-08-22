# Self-hosted speech recognition and the pronunciation engine

How pronunciation is scored, why it is split into two stages, and why a
language model is never the source of the number on screen.

---

## Why a two-stage pipeline, and not a language model

This is the most important design decision in the project.

Pronunciation assessment is fundamentally a comparison problem: how close was
what the child said to the target word? That comparison has to be answered by
measurement, not by guessing from spelling. A large language model operates on
**text** - given only a transcript, it can do no better than infer
pronunciation quality from spelling differences, which is not measurement. Two
children whose speech differs audibly can produce an identical transcript, and
a model would have no way to tell them apart.

So the pipeline is deliberately split into two stages that never share a
responsibility:

```
Flutter  ──HTTPS──>  Django  ──>  Whisper (self-hosted)  ──>  transcript
                                        │
                                        ▼
                              PronunciationEngine (deterministic Python)
                                        │
                                        ▼
                              score + feedback  ──>  PostgreSQL
```

- **Whisper only ever answers "what did the model think was said."** It is a
  speech-to-text engine, nothing more. It never produces a score.
- **The pronunciation engine only ever answers "how well was it said."** It
  never touches audio - it works entirely from the reference word, the
  recognised text, and Whisper's own confidence signal.
- **The optional LLM feedback layer only rewords.** When enabled, it turns
  numbers the engine already produced into warmer phrasing. It never sees
  audio and never alters a score.
- **String similarity is not the score.** A phonetic-feature comparison
  (below) stands in its place; naive edit distance over raw text is not used
  as the pronunciation measurement anywhere in this pipeline.

Conflating "what was transcribed" with "how well was it pronounced" - scoring
directly off whatever a transcription service returns - is the failure mode
this split exists to avoid.

Nothing in this pipeline is a paid API. Everything after the recording leaves
the child's device runs inside the Django process, on the server's own CPU.

---

## Stage 1: Whisper, self-hosted

Recognition runs via [`faster-whisper`](https://github.com/SYSTRAN/faster-whisper),
a CTranslate2 reimplementation of OpenAI's Whisper - same model weights,
meaningfully faster on CPU, and installable on Windows with no native
toolchain. `WhisperSpeechRecognitionService`
([`recognition/whisper_service.py`](../backend/apps/practice/services/recognition/whisper_service.py))
is the only module that imports it, and does so lazily inside the method so
the library never loads during tests.

Configuration (`backend/.env`, all optional - defaults shown):

| Setting | Default | Notes |
| --- | --- | --- |
| `SPEECH_PROVIDER` | `mock` | `whisper` to transcribe for real; the mock returns a fixed transcript with no model load |
| `WHISPER_MODEL_SIZE` | `base` | Larger models (`small`, `medium`, ...) trade a slower first download and slower inference for better accuracy |
| `WHISPER_DEVICE` | `cpu` | `cuda` if a GPU is available |
| `WHISPER_COMPUTE_TYPE` | `int8` | Quantisation; `int8` is the fast, low-memory CPU default |

The model is loaded once per process (`@lru_cache`) and reused for every
request after the first. On this project's own hardware, transcribing one
real spoken word with the cached `base` model took well under a second on
CPU. The **first** run is a different story: downloading a fresh model from
an unauthenticated Hugging Face Hub connection was measured at over two
hours for a 140 MB model. That is a download-throughput problem, not a
compute problem - once the weights are cached, recognition is fast.

Silence handling: a Whisper segment with `no_speech_prob >= 0.6` is treated as
not real speech, so a hallucinated word never masquerades as a genuine
attempt. If every segment is discarded this way, the service raises
`NoSpeechDetected` - handled upstream as a real, storable result ("we could
not hear anything"), never as an error.

Confidence: Whisper has no calibrated confidence score. `avg_logprob` (a log
probability, typically near 0 when the model was sure, more negative when it
was not) is exponentiated back into a 0-100 range - the standard community
proxy. It is directionally reliable, not a precise probability, and is
documented as such everywhere it is used.

---

## Stage 2: the pronunciation engine

`PronunciationEngine`
([`pronunciation/engine.py`](../backend/apps/practice/services/pronunciation/engine.py))
is deterministic Python - no model call, no network call, identical behaviour
in every environment. It runs the same way in tests as in production, because
there is nothing external to mock.

### Similarity: phonetic-feature distance, not string distance

Both the reference word and the recognised text are converted to phonemes
(see G2P below), then compared with [`panphon`](https://github.com/dmort27/panphon),
which maps each IPA segment to a vector of articulatory features - voicing,
place, manner, and so on - and measures a weighted feature edit distance over
those vectors rather than over raw characters.

This is why "bola" said as "bota" costs something meaningful: one consonant
swap that changes several articulatory features, not a single character-edit
the way a plain string diff would report it. It is a genuinely different
measurement from `SequenceMatcher` or Levenshtein distance over text.

This is a **text-level proxy, not acoustic analysis** - a real limitation
worth stating plainly. It compares phoneme strings derived from Whisper's
transcript and from the reference word; it never touches the audio itself.
It sits closer in spirit to Goodness-of-Pronunciation scoring than to naive
string matching, but a true acoustic GOP score would need frame-level
posteriors from a phoneme-level acoustic model, which is out of scope here.

### Grapheme-to-phoneme (G2P)

| Language | Approach |
| --- | --- |
| English | [`g2p_en`](https://github.com/Kyubyong/g2p) - CMU Pronouncing Dictionary plus a trained model for out-of-dictionary words, ARPAbet output mapped to IPA |
| Malay | A hand-written deterministic ruleset ([`g2p_malay.py`](../backend/apps/practice/services/pronunciation/g2p_malay.py)) |

No maintained Malay G2P library exists the way CMU's dictionary does for
English. Standard Malay orthography is unusually regular, though, so a rule
table is a defensible, honestly approximate stand-in - closer to a spelling
system that predicts pronunciation than English's is. Rules follow the
mapping documented at
[Wikipedia's Help:IPA/Indonesian and Malay](https://en.wikipedia.org/wiki/Help:IPA/Indonesian_and_Malay).

**Known limitation, stated rather than hidden**: Malay spelling does not
distinguish the two sounds written "e" - schwa (the common case) from
close-mid /e/ (in some loanwords) - without a diacritic most text does not
carry. The ruleset always resolves "e" to schwa, the statistically dominant
reading. A handful of words ("meja", among them) will be transcribed with the
wrong vowel as a result. This is a property of the writing system, not a bug
in the rule table - the same ambiguity exists for a human reader without
prior knowledge of the word.

English's G2P needs two NLTK resources on first use
(`averaged_perceptron_tagger_eng`, `cmudict`), downloaded automatically if
missing - see [development.md](development.md) to fetch them ahead of time.

### Completeness

How much of the reference word's phoneme count showed up in what was spoken,
as a ratio capped at 100 - a child who trails off mid-word produces fewer
phonemes than the target and is penalised; a longer-than-expected utterance
is capped, not rewarded, since padding is not completeness.

### The final score

```
final = (similarity_weight × similarity)
      + (confidence_weight × confidence)
      + (completeness_weight × completeness)
```

Defaults: similarity 0.5, confidence 0.3, completeness 0.2 - configurable via
`PRONUNCIATION_WEIGHT_SIMILARITY` / `_CONFIDENCE` / `_COMPLETENESS` in
`backend/.env` (`PRONUNCIATION_SCORE_WEIGHTS` in `settings.py`), not
hardcoded. The result is clamped to 0-100 and rounded.

### Structured error detection

A Levenshtein-style alignment over phoneme *lists* (not characters, so a
multi-character IPA symbol like "tʃ" is one edit unit, never split) walks the
reference and spoken phoneme sequences and classifies each difference:

| Type | When |
| --- | --- |
| `missing_ending` | A phoneme was dropped, and nothing follows it - the word was cut short |
| `missing_phoneme` | A phoneme was dropped mid-word |
| `wrong_consonant` | A consonant was swapped for a different consonant |
| `wrong_vowel` | A vowel was swapped for a different vowel |
| `substitution` | A consonant was swapped for a vowel or vice versa |
| `extra_sound` | A phoneme was inserted that the reference does not have |

Every error carries `expected` and `detected` phonemes, e.g.
`{"type": "missing_ending", "expected": "h", "detected": ""}`. **Only errors
the alignment actually supports are reported** - the engine has no
frame-level acoustic signal, only two phoneme sequences, so nothing beyond
what an edit-script alignment between them can justify is ever invented. Two
of the project's own worked examples ("kucing"→"kucin", "elephant"→"elepant")
turn out to align as a single wrong-consonant substitution (ŋ→n, f→p) rather
than a deletion, because the phoneme *count* did not actually change - a more
precise classification than the informal "missing ending" label might
suggest, and the engine reports what the alignment actually found.

### Deterministic feedback

One sentence, chosen by score band, written in the language being practised
(a Malay learner is never praised in English):

| Band | English | Bahasa Melayu |
| --- | --- | --- |
| 90-100 | "Excellent! Your pronunciation is very clear!" | "Cemerlang! Sebutan anda sangat jelas!" |
| 75-89 | "Great job! You're very close." | "Syabas! Sebutan anda hampir tepat." |
| 50-74 | "Nice try! Listen again and say it slowly." | "Bagus dicuba! Dengar sekali lagi dan sebut perlahan-lahan." |
| 0-49 | "Let's practice together. You can do it!" | "Jom kita berlatih bersama. Anda pasti boleh!" |

Always available - no model call, nothing that can be down. An optional LLM
layer may rephrase this sentence (see below), but it never touches the score,
and the app keeps working exactly like this if that layer is disabled or
fails.

---

## No prosody metric - and that is deliberate

There is no prosody, intonation, or stress score anywhere in this
architecture, for either language. Whisper plus a text-level phonetic
comparison has no acoustic signal to derive stress, intonation or rhythm
from. Rather than fabricate one, the metric simply does not exist here - not
a `null` placeholder for something that might one day be measured, just
absent from the model, the API response, and the UI. That is the same
principle the error-detection layer applies at a finer grain: report only
what the available signal actually supports.

---

## The service boundary

```
Whisper (real)  ──>  WhisperSpeechRecognitionService  ──┐
Mock (tests)    ──>  MockSpeechRecognitionService     ──┴──>  RecognitionResult
                                                                    │
                                                                    ▼
                                                   PronunciationEngine (always real, never mocked)
                                                                    │
                                                                    ▼
                                                       PronunciationEngineResult ──> PostgreSQL
```

Only recognition is swappable - the engine that scores the transcript is
deterministic and identical in every environment, so there is nothing to
select there. `get_recognition_service()`
([`services/factory.py`](../backend/apps/practice/services/factory.py))
returns the Whisper service when `SPEECH_PROVIDER=whisper`, otherwise the
mock. Both are honoured by the same `SpeechRecognitionService` interface, so
`PracticeEvaluationService` never knows which one it is talking to.

---

## Audio format

The app records **16 kHz, mono, 16-bit PCM WAV**, which is what Whisper
expects. Sending a compressed format risks a worse transcription for reasons
that have nothing to do with the child's pronunciation.

Recordings are validated before upload - empty and oversized (>5 MB) clips
are rejected client- and server-side.

---

## Error handling

Recognition failures are classified and translated into child-safe messages.
The technical reason is logged server-side and never returned:

| Condition | What the child sees |
| --- | --- |
| Model failed to load | "Speech assessment is not available right now." |
| Transcription raised | "Speech assessment is temporarily unavailable. Please try again." |
| No usable speech detected | "We could not hear anything. Try again and speak clearly." |

**Silence is not an error.** It still stores an attempt (useful information
for a parent), awards 0 points, and shows the message above rather than
failing the request.

---

## Text-to-speech

The **listen** button uses on-device TTS (`flutter_tts`), unrelated to
recognition entirely. A child taps it repeatedly per word; routing that
through a network call would add latency for no pedagogical gain and would
stop the feature working offline.

---

## Cost and resource control

1. Assessment fires only on a deliberate stop, never from a widget rebuild.
2. Audio is validated before upload.
3. TTS is on-device.
4. `SPEECH_PROVIDER=mock` by default - a fresh checkout needs no model
   download and no CPU cost.
5. No test in either suite loads a real Whisper model or calls any network
   service.
6. `STORE_AUDIO=False` by default.
7. There is no paid API anywhere in this pipeline - recognition and scoring
   both run on infrastructure this project already controls.

---

## Optional LLM feedback

An optional layer (`ENABLE_AI_FEEDBACK`, `AI_PROVIDER`) can rephrase the
deterministic sentence above into warmer, more specific wording. It receives
only the numbers the engine already produced (`similarity`, `confidence`,
the top error type) - never audio, never a child's name or account
identifier - and every failure path (down, slow, misconfigured, an unusable
response) falls back to the deterministic sentence. See
[`services/ai/base.py`](../backend/apps/practice/services/ai/base.py).
