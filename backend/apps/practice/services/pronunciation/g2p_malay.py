"""Malay text to IPA, via Epitran (`msa-Latn`).

Phase 2.5 replaced this module's original hand-written rule table with
Epitran, a rule/mapping-based grapheme-to-phoneme engine with a dedicated
Malay transducer. No native toolchain is required to install it - see
`requirements.txt`.

Kept as a thin wrapper with the same `.phonemes()` / `.to_ipa()` interface as
`EnglishG2P` (see `g2p_english.py`), so the rest of the pronunciation engine
(`engine.py`, `error_detection.py`, `debug.py`) never has to know which
grapheme-to-phoneme approach backs which language.

**Behavioural differences from the previous hand-written table, stated
plainly rather than silently changed:**

- Epitran always resolves written "e" to close-mid /e/, never to schwa. The
  old table had the opposite bias (always schwa, wrong for words like
  "meja"). Neither is a complete model of Malay's schwa/e distinction -
  standard orthography does not mark it, so no purely text-based G2P can get
  every word right without a pronunciation dictionary. Epitran fixes the
  documented "meja" case; it will now be wrong in the direction the old
  table used to be right (a word that is genuinely schwa, e.g. the first
  syllable of "sepuluh", comes out as /e/).
- Diphthongs are realised as vowel+glide (e.g. "pandai" -> `p a n d a j`,
  "harimau" -> `h a r i m a w`) rather than as single diphthong units
  (`aɪ`, `aʊ`). Both are legitimate IPA conventions for Malay; this changes
  which symbols show up in `errors`, not the underlying accuracy.
- Word-final /k/ is **not** realised as a glottal stop (unlike the old
  table's explicit rule for it, e.g. "tidak" -> `t i d a k`, not `...ʔ`).
  This is a real regression against one specific, well-documented Malay
  phonological rule - tracked as a known limitation rather than patched
  back in, since silently special-casing one segmenter's output would
  undermine the reason to prefer a maintained library over hand-written
  rules in the first place.

Affricates come back as tie-bar sequences (`t͡ʃ`, `d͡ʒ`) rather than the plain
two-character `tʃ`/`dʒ` the old table used. `Epitran.trans_list()` already
returns each affricate as a single list entry, so this needs no special
handling anywhere else in the pipeline - alignment and phonetic distance both
operate one entry at a time, panphon segments tie-bar sequences correctly.
"""


class MalayG2P:
    def __init__(self):
        self._epi = None  # loaded lazily; see _ensure_loaded

    def _ensure_loaded(self):
        if self._epi is None:
            import epitran

            self._epi = epitran.Epitran("msa-Latn")

    def phonemes(self, text):
        """Return a list of IPA phoneme units - one list entry per sound,
        even where the IPA symbol itself is multiple characters (e.g. the
        tie-bar affricate 'd͡ʒ'). Kept separate from raw text so
        alignment-based error detection can compare whole phonemes rather
        than substrings of them."""
        self._ensure_loaded()
        return self._epi.trans_list(text.lower().strip())

    def to_ipa(self, text):
        """Return an IPA string for `text`."""
        self._ensure_loaded()
        return self._epi.transliterate(text.lower().strip())
