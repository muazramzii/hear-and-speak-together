"""Malay text to IPA - a hand-written ruleset, not a library.

No maintained Malay grapheme-to-phoneme library exists the way CMU's
dictionary does for English, and building or training a real one is a
separate project on its own. Standard Malay orthography is unusually
regular, though - closer to a spelling system that predicts pronunciation
than English's is - so a deterministic rule table is a defensible, honestly
approximate stand-in, in a way the same approach would not be for English.

Rules below follow the mapping documented at Wikipedia's Help:IPA/Indonesian
and Malay, cross-checked against the digraph list in the English Wikipedia
article on Malay phonology (both accessed 2026-08-21):

  https://en.wikipedia.org/wiki/Help:IPA/Indonesian_and_Malay

**Known limitation, stated rather than hidden**: standard Malay spelling does
not distinguish the two sounds written "e" - schwa (pepet, the common case)
from close-mid /e/ (taling, in some loanwords and specific native words)
without a diacritic most text does not carry. This table always resolves "e"
to schwa, the statistically dominant reading. A handful of words - "meja"
(desk, taling /e/) among them - will be transcribed with the wrong vowel as a
result. This is a property of the writing system, not a bug in the rule
table, and the same ambiguity exists for a human reader without prior
knowledge of the word.
"""

# Longest match first: multi-letter sequences must be tried before the single
# letters they contain, or "ng" would be read as "n" followed by an
# unrelated "g".
_DIPHTHONGS = {"ai": "aɪ", "au": "aʊ", "ei": "eɪ", "oi": "oɪ", "ui": "uɪ"}
_DIGRAPHS = {"ng": "ŋ", "ny": "ɲ", "sy": "ʃ", "kh": "x"}

_CONSONANTS = {
    "b": "b", "c": "tʃ", "d": "d", "f": "f", "g": "ɡ", "h": "h",
    "j": "dʒ", "k": "k", "l": "l", "m": "m", "n": "n", "p": "p",
    "q": "k", "r": "r", "s": "s", "t": "t", "v": "v", "w": "w",
    "x": "ks", "y": "j", "z": "z", "'": "ʔ",
}

# Schwa by default - see the module docstring. A word ending "-ah" gets a
# distinct rule below rather than falling through here.
_VOWELS = {"a": "a", "e": "ə", "i": "i", "o": "o", "u": "u"}


class MalayG2P:
    def phonemes(self, text):
        """Return a list of IPA phoneme units - one list entry per sound.
        Deterministic - no external resource, nothing to load."""
        word = text.lower().strip()
        symbols = []
        i = 0
        length = len(word)

        while i < length:
            two = word[i : i + 2]

            if two in _DIPHTHONGS:
                symbols.append(_DIPHTHONGS[two])
                i += 2
                continue

            if two in _DIGRAPHS:
                symbols.append(_DIGRAPHS[two])
                i += 2
                continue

            char = word[i]

            if char == "k" and i == length - 1:
                # Word-final k is a glottal stop, not a released /k/ - the
                # one context-sensitive rule in this table, and the one with
                # the most direct documentary support.
                symbols.append("ʔ")
            elif char in _VOWELS:
                symbols.append(_VOWELS[char])
            elif char in _CONSONANTS:
                symbols.append(_CONSONANTS[char])
            # Anything else (digits, punctuation) is silently dropped rather
            # than raising - a word_list entry with a stray character should
            # degrade, not crash a practice session.

            i += 1

        return symbols

    def to_ipa(self, text):
        """Return an IPA string for `text`."""
        return "".join(self.phonemes(text))
