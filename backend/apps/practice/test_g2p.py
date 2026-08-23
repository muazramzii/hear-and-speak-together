"""Phase 2.5 tests: the bilingual grapheme-to-phoneme pipeline.

English (`g2p_en`, dictionary-based) and Malay (Epitran `msa-Latn`,
mapping-based) are different libraries behind the same `.phonemes()` /
`.to_ipa()` interface (see `g2p_english.py` and `g2p_malay.py`). These tests
pin real output from both, and specifically exercise the documented
behaviour changes from replacing the old hand-written Malay rule table with
Epitran - so a future change to either library is caught here, not
discovered later as an unexplained score shift.
"""

from django.test import TestCase

from .services.pronunciation.g2p_english import EnglishG2P
from .services.pronunciation.g2p_malay import MalayG2P


class EnglishG2PTests(TestCase):
    def test_a_known_word_produces_the_expected_phonemes(self):
        phonemes = EnglishG2P().phonemes("elephant")

        self.assertEqual(phonemes, ["ɛ", "l", "ə", "f", "ə", "n", "t"])


class MalayG2PTests(TestCase):
    """Epitran (msa-Latn) replaced the hand-written rule table in
    Phase 2.5. See g2p_malay.py's module docstring for the full list of
    behavioural differences this locks in."""

    def test_a_simple_word(self):
        self.assertEqual(MalayG2P().phonemes("bola"), ["b", "o", "l", "a"])

    def test_affricates_come_back_as_single_tie_bar_units(self):
        # Not the old table's plain "dʒ"/"tʃ" - Epitran's tie-bar notation.
        # Still exactly one list entry, which is what alignment relies on.
        phonemes = MalayG2P().phonemes("gajah")

        self.assertEqual(phonemes, ["ɡ", "a", "d͡ʒ", "a", "h"])
        self.assertEqual(len(phonemes), 5)

    def test_the_digraph_ng_is_one_consonant(self):
        phonemes = MalayG2P().phonemes("kucing")

        self.assertEqual(phonemes, ["k", "u", "t͡ʃ", "i", "ŋ"])

    def test_diphthongs_decompose_into_vowel_plus_glide(self):
        # A documented behaviour change from the old table, which produced
        # single diphthong units ("aɪ") instead.
        self.assertEqual(
            MalayG2P().phonemes("pandai"), ["p", "a", "n", "d", "a", "j"]
        )

    def test_word_final_k_is_not_a_glottal_stop(self):
        # A documented, known limitation (see g2p_malay.py): the old table
        # had an explicit rule for this; Epitran does not model it. Pinned
        # here so it is a visible, deliberate choice if it ever changes.
        self.assertEqual(
            MalayG2P().phonemes("tidak"), ["t", "i", "d", "a", "k"]
        )

    def test_input_is_lowercased(self):
        self.assertEqual(MalayG2P().phonemes("BOLA"), MalayG2P().phonemes("bola"))

    def test_to_ipa_joins_the_same_phonemes(self):
        g2p = MalayG2P()

        self.assertEqual(g2p.to_ipa("bola"), "".join(g2p.phonemes("bola")))
