"""Classifies pronunciation mistakes from a phoneme-level alignment.

Only infers what the phoneme comparison actually supports - the app has no
frame-level acoustic signal to point at, only two phoneme sequences, so error
types are limited to what an edit-script alignment between them can justify.
No phoneme analysis is invented beyond that.
"""

from dataclasses import dataclass

_VOWEL_SYMBOLS = {
    # English (see g2p_english.py's ARPAbet table). Diphthongs are single
    # units here because g2p_en/ARPAbet represents them that way.
    "ɑ", "æ", "ʌ", "ɔ", "aʊ", "aɪ", "ɛ", "ɝ", "ɚ", "eɪ", "ɪ", "i",
    "oʊ", "ɔɪ", "ʊ", "u", "ə",
    # Malay (see g2p_malay.py, Epitran msa-Latn). "i" and "u" above are
    # shared with English. Epitran decomposes Malay diphthongs into a vowel
    # plus a glide ("pandai" -> ...a j) rather than a single diphthong
    # symbol, so no Malay-specific diphthong entries are needed here.
    "a", "e", "o",
}


@dataclass(frozen=True)
class PronunciationError:
    type: str  # "missing_ending" | "missing_phoneme" | "wrong_consonant" |
    #             "wrong_vowel" | "substitution" | "extra_sound"
    expected: str
    detected: str

    def to_dict(self):
        return {"type": self.type, "expected": self.expected, "detected": self.detected}


def _is_vowel(phoneme):
    return phoneme in _VOWEL_SYMBOLS


def align(reference, spoken):
    """Levenshtein alignment over phoneme *lists*, not characters - so a
    multi-character IPA symbol like 'tʃ' is one edit unit, never split.

    Returns a list of ('match' | 'substitute' | 'delete' | 'insert', ref, spoken)
    tuples in order. A textbook edit-distance DP with backtrace; substitution,
    insertion and deletion all cost 1, ties broken toward substitution over a
    delete+insert pair, which reads more naturally for a single wrong sound.
    """
    rows, cols = len(reference) + 1, len(spoken) + 1
    cost = [[0] * cols for _ in range(rows)]
    for r in range(rows):
        cost[r][0] = r
    for c in range(cols):
        cost[0][c] = c

    for r in range(1, rows):
        for c in range(1, cols):
            if reference[r - 1] == spoken[c - 1]:
                cost[r][c] = cost[r - 1][c - 1]
            else:
                cost[r][c] = 1 + min(
                    cost[r - 1][c],  # delete from reference
                    cost[r][c - 1],  # insert into spoken
                    cost[r - 1][c - 1],  # substitute
                )

    ops = []
    r, c = len(reference), len(spoken)
    while r > 0 or c > 0:
        if r > 0 and c > 0 and reference[r - 1] == spoken[c - 1]:
            ops.append(("match", reference[r - 1], spoken[c - 1]))
            r, c = r - 1, c - 1
        elif r > 0 and c > 0 and cost[r][c] == cost[r - 1][c - 1] + 1:
            ops.append(("substitute", reference[r - 1], spoken[c - 1]))
            r, c = r - 1, c - 1
        elif r > 0 and cost[r][c] == cost[r - 1][c] + 1:
            ops.append(("delete", reference[r - 1], None))
            r -= 1
        else:
            ops.append(("insert", None, spoken[c - 1]))
            c -= 1

    ops.reverse()
    return ops


def detect_errors(reference_phonemes, spoken_phonemes, limit=5):
    """The errors a phoneme-level diff actually supports, worst-context
    first is not attempted - reported in the order they occur in the word,
    which is how a child (or a parent reading the feedback) would follow
    them."""
    ops = align(reference_phonemes, spoken_phonemes)
    errors = []

    for index, (kind, expected, detected) in enumerate(ops):
        if kind == "match":
            continue

        if kind == "delete":
            is_trailing = not any(
                later_kind != "insert" for later_kind, *_ in ops[index + 1 :]
            )
            error_type = "missing_ending" if is_trailing else "missing_phoneme"
            errors.append(
                PronunciationError(type=error_type, expected=expected, detected="")
            )
        elif kind == "insert":
            errors.append(
                PronunciationError(type="extra_sound", expected="", detected=detected)
            )
        elif kind == "substitute":
            if _is_vowel(expected) and _is_vowel(detected):
                error_type = "wrong_vowel"
            elif not _is_vowel(expected) and not _is_vowel(detected):
                error_type = "wrong_consonant"
            else:
                error_type = "substitution"
            errors.append(
                PronunciationError(type=error_type, expected=expected, detected=detected)
            )

    return errors[:limit]
