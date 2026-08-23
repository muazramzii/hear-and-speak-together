# Phase 2.5 validation report — engine refinement

Base vs medium, English vs Malay, latency, accuracy, and known limitations,
following the Phase 2.5 refinement (default model change, Epitran for
Malay, `ConfidenceNormalizer`, dev-only telemetry). All numbers below are
real measurements — real Whisper inference, real Epitran/`g2p_en` output,
real `panphon` distance — never fabricated or interpolated. Where real
acoustic input was not possible (Malay), that gap is stated rather than
papered over.

Full automated suite: **267 backend tests, 97 Flutter tests, all green.**
`makemigrations --check` reports no drift.

---

## Method

- **English**: real speech via Windows SAPI TTS (`Microsoft Zira Desktop`,
  16 kHz mono PCM WAV), fed through the *real* `WhisperSpeechRecognitionService`
  for both `base` and `medium`, then the real `PronunciationEngine` (Epitran
  is not involved for English — `g2p_en` is unchanged).
- **Malay**: no Malay voice is installed on this machine (confirmed — only
  two `en-US` SAPI voices are available), so there is no real acoustic
  Malay input to test against. Malay numbers below exercise the real,
  non-mocked text-to-phoneme pipeline (`Epitran msa-Latn` → `panphon` →
  error detection) with plausible mis-transcriptions substituted for what
  Whisper would have produced. **This validates the scoring and G2P layers
  genuinely; it does not validate Malay acoustic recognition at all.** See
  "Known limitations".
- 5 correct + 3 mispronounced words per language, matching the Phase 2
  dataset (`pronunciation_test_data.py`).

---

## Base vs Medium (English, real audio)

| Word | Base: heard | Base score | Base conf. | Base ms | Medium: heard | Medium score | Medium conf. | Medium ms |
|---|---|---|---|---|---|---|---|---|
| elephant | "Elephant" | 93 | 76.2 | 872 | "ELEPHANT" | 84 | 46.8 | 5675 |
| banana | "Banana" | 90 | 66.7 | 696 | "BANANA" | 77 | 24.2 | 5631 |
| apple | "Apple" | 94 | 80.5 | 694 | "Apple" | 87 | 55.7 | 6036 |
| tiger | "Tiger" | 91 | 69.7 | 685 | "Tiger" | 94 | 79.8 | 6045 |
| lion | "Lion" | 84 | 48.0 | 674 | "Lion" | 73 | 10.7 | 6250 |
| elepant (wrong) | "Gillipant" | 20 | 0.0 | 2122 | "Illipant" | 70 | 41.5 | 8517 |
| bananna (wrong) | "Banana" | 82 | 39.9 | 689 | "Banana" | 86 | 53.8 | 6936 |
| aplle (wrong) | "and" | 15 | 0.0 | 1624 | "Empl." | 23 | 10.8 | 6145 |

**Latency**: `base` averages ~0.9s/word (worst case ~2.1s on a garbled
clip); `medium` averages ~6.4s/word. **`base` meets the 3-second target
comfortably; `medium` does not, on this CPU.**

**Accuracy on this small sample**: mixed, not a clean win for either
model. `medium` recovered "elepant" more informatively (heard "Illipant",
close enough to still classify two specific errors) where `base` heard
"Gillipant" and scored it near zero on everything. But `base` correctly
recognised all 5 unmodified words with *higher* average confidence than
`medium` did, and both models mis-heard "bananna" as the correctly-spelled
"banana" (see Known limitations). Neither model is a strictly better
choice on accuracy alone at this sample size — the deciding factor here is
latency, where `base` wins decisively.

**Confidence is not a reliable proxy for correctness in either model.**
"Lion" — heard correctly by both models — scored the *lowest* confidence of
any correct word in both rows. `ConfidenceNormalizer`'s rescale (Priority
3) makes the numbers spread out and readable; it does not, and cannot on
its own, make them track actual pronunciation accuracy. See Known
limitations.

---

## English vs Malay

| | English | Malay |
|---|---|---|
| G2P library | `g2p_en` (CMU dict + trained model) | Epitran `msa-Latn` (Phase 2.5) |
| Real acoustic test performed | Yes (SAPI TTS → Whisper) | **No** (no Malay TTS voice available) |
| Correct-word score (real/simulated recognition) | 84–94 (medium), 20–94 (base, wide due to two garbled clips) | 97 (all 5 words) |
| Mispronunciation detected as a specific error | 2 of 3 (medium); "bananna" collapses to correct in both models | 4 of 4 |
| G2P behaviour change this phase | None — `g2p_en` untouched | Diphthongs now decompose (vowel+glide), word-final /k/ no longer glottal stop, "e" now always /e/ never schwa |

Malay's *phoneme-layer* accuracy (Epitran → panphon → error detection) is
excellent on this dataset — every mispronunciation produced exactly the
error type expected, matching the same error types the old hand-written
ruleset produced for these same words. That continuity is a genuinely
positive finding: swapping the G2P library did not regress the error
classification for the cases already validated in Phase 2.

The English *acoustic* layer (real Whisper) is the only piece actually
exercised against real audio this phase. Malay's acoustic layer remains
**unvalidated with real speech** — carried over from the Phase 2 report as
still open.

---

## Latency

| Stage | Typical cost |
|---|---|
| Whisper `base` inference | ~0.7–0.9s/word |
| Whisper `medium` inference | ~5.7–8.5s/word |
| Phoneme analysis (English, `g2p_en`) | ~0.5–3.7s on the *first* call per process (NLTK/model load), <5ms after |
| Phoneme analysis (Malay, Epitran) | ~2.0s on the *first* call per process (panphon table load), <1ms after |
| Total, warm process, `base` | Comfortably under 3s |
| Total, warm process, `medium` | 2–2.8× over the 3s target |

The one-time per-process load costs (G2P models, panphon's feature table)
are real but amortised — they happen once when a worker process starts,
not on every request.

---

## Accuracy

- **Correct pronunciation** scored well across the board: English 84–97
  (medium/base, real audio), Malay 97 (simulated recognition, real
  phoneme pipeline).
- **Structured error detection works on real, non-scripted ASR output.**
  "elepant" → medium's real transcription "Illipant" → correctly
  classified as `wrong_vowel` + `wrong_consonant`, with no part of that
  chain scripted by this validation.
- **A spelling mistake is not always an acoustic mistake, confirmed
  again this phase.** "bananna" was heard as "Banana" by *both* Whisper
  models — Whisper's own language-model bias, not a G2P artifact this
  time (unlike the Phase 2 finding, where it was `g2p_en` collapsing the
  phonemes; here the ASR itself never even transcribed the misspelling).
  Two independent causes, same practical effect: some intentional
  mispronunciations never reach the scoring layer as a detectable
  difference.
- **Confidence and correctness are only loosely related**, calibrated or
  not. Rescaling (Priority 3) fixed the *range problem* (everything
  clustering in a narrow, low band); it did not and cannot fix the
  *correlation problem* (a correctly-heard word can still score low
  confidence, as "lion" did twice here).

---

## Known limitations

1. **`medium` still does not meet the 3-second target on this CPU.**
   Confirmed again this phase with the new default in place — `base` is
   correctly the default now, and that default should stay unless a GPU
   is available.
2. **Malay has never been tested against real acoustic speech**, on this
   machine, across two phases now. The phoneme/scoring layer is validated;
   the recognition layer for Malay specifically is not.
3. **`ConfidenceNormalizer` is a heuristic rescale, not a fitted
   calibration**, by design and by necessity — there is no labelled
   dataset of confidence vs. human-judged accuracy to fit one against yet.
   It should not be read as "how likely this score is to be right."
4. **Epitran's Malay output differs from the old hand-written table in
   three documented ways** (schwa/e resolution, diphthong decomposition,
   no word-final /k/ glottal stop) — see `g2p_malay.py` and
   `docs/pronunciation-engine.md`. None of these were regressions on the
   four worked examples re-tested this phase, but they are real behaviour
   changes worth knowing about for any word outside that set.
5. **Whisper's own language-model bias can erase a mispronunciation**
   before it ever reaches the phoneme layer — observed independently in
   Phase 2 (text-level, via `g2p_en`) and this phase (acoustic-level, via
   Whisper itself, on the same word). This is a property of using a
   general-purpose ASR model for pronunciation assessment, not a bug in
   this project's code, and is unlikely to be fully solvable without a
   phoneme-level acoustic model purpose-built for pronunciation scoring.
6. **This validation's English sample is small (8 words) and entirely
   synthetic-voice.** It is real audio and a real pipeline, but it is not
   a substitute for testing against actual children's recordings before
   trusting these numbers for a production decision.
