"""English text to IPA, via `g2p_en`.

`g2p_en` wraps the CMU Pronouncing Dictionary for known words and a small
trained model for anything out-of-dictionary, and returns ARPAbet phonemes
(e.g. "elephant" -> ['EH1', 'L', 'AH0', 'F', 'AH0', 'N', 'T']) rather than
IPA. The mapping below is the standard ARPAbet-to-IPA table; the one
deliberate deviation from a flat lookup is AH0 and ER0, which ARPAbet
convention realises as schwa (@) and rhotic schwa rather than as the stressed
vowels AH/ER normally represent - collapsing that distinction would make
every unstressed syllable sound like a fully stressed one to the phonetic
distance layer.

Requires the NLTK resources `averaged_perceptron_tagger_eng` and `cmudict`.
Downloaded automatically on first use if missing, which needs internet
access - see docs/development.md to fetch them ahead of time instead.
"""

import logging

logger = logging.getLogger(__name__)

_ARPABET_TO_IPA = {
    # Consonants
    "B": "b", "CH": "tʃ", "D": "d", "DH": "ð", "F": "f", "G": "ɡ",
    "HH": "h", "JH": "dʒ", "K": "k", "L": "l", "M": "m", "N": "n",
    "NG": "ŋ", "P": "p", "R": "ɹ", "S": "s", "SH": "ʃ", "T": "t",
    "TH": "θ", "V": "v", "W": "w", "Y": "j", "Z": "z", "ZH": "ʒ",
    # Vowels (stress digit stripped before lookup)
    "AA": "ɑ", "AE": "æ", "AH": "ʌ", "AO": "ɔ", "AW": "aʊ", "AY": "aɪ",
    "EH": "ɛ", "ER": "ɝ", "EY": "eɪ", "IH": "ɪ", "IY": "i", "OW": "oʊ",
    "OY": "ɔɪ", "UH": "ʊ", "UW": "u",
}

# ARPAbet convention: an unstressed AH/ER is realised as schwa, not as the
# full vowel the bare symbol normally represents.
_UNSTRESSED_OVERRIDES = {"AH0": "ə", "ER0": "ɚ"}


class EnglishG2P:
    def __init__(self):
        self._g2p = None  # loaded lazily; NLTK data access happens here

    def _ensure_loaded(self):
        if self._g2p is None:
            from g2p_en import G2p

            self._g2p = G2p()

    def phonemes(self, text):
        """Return a list of IPA phoneme units - one list entry per sound,
        even where the IPA symbol itself is multiple characters (e.g. 'tʃ').
        Kept separate from raw text so alignment-based error detection can
        compare whole phonemes rather than substrings of them."""
        self._ensure_loaded()

        symbols = []
        for phoneme in self._g2p(text):
            if phoneme in _UNSTRESSED_OVERRIDES:
                symbols.append(_UNSTRESSED_OVERRIDES[phoneme])
                continue

            bare = phoneme.rstrip("012")  # strip the stress digit, if any
            ipa = _ARPABET_TO_IPA.get(bare)
            if ipa is not None:
                symbols.append(ipa)
            elif bare.isalpha():
                # Punctuation g2p_en occasionally emits (e.g. a space token)
                # is silently dropped; an unrecognised *phoneme* symbol is
                # logged, because that would mean the table above is missing
                # an entry - a bug, not expected input.
                logger.warning("Unmapped ARPAbet phoneme: %r", phoneme)

        return symbols

    def to_ipa(self, text):
        """Return an IPA string for `text`, or '' if it produced no
        phonemes (e.g. empty input)."""
        return "".join(self.phonemes(text))
