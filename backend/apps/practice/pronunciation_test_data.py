"""The Phase 2 validation dataset: known-correct and intentionally
mispronounced words for English and Malay, used to check that the
pronunciation engine scores consistently - a correct word should always
score well, and each mispronunciation should score measurably lower than
its correct counterpart.

Exposed to the sandbox screen via `PronunciationTestWordsView` and used
directly by `test_pronunciation_debug.py`.
"""

PRONUNCIATION_TEST_WORDS = {
    "en": {
        "words": ["elephant", "banana", "apple", "tiger", "lion"],
        "mispronunciations": {
            "elephant": "elepant",
            "banana": "bananna",
            "apple": "aplle",
        },
    },
    "ms": {
        "words": ["bola", "gajah", "kucing", "meja", "pensel"],
        "mispronunciations": {
            "bola": "bota",
            "gajah": "gaja",
            "kucing": "kucin",
            "meja": "mejaa",
        },
    },
}
