"""Phonetic-feature distance between two phoneme sequences, via panphon.

This is the layer that keeps scoring from collapsing back into plain text
similarity. `panphon` maps each IPA segment to a vector of articulatory
features (voicing, place, manner, ...) and measures edit distance over those
vectors, so "bola" vs "bota" costs something meaningful - one consonant swap
that changes several articulatory features - rather than the single
character-edit that a plain string diff would report.

**This is a text-level proxy, not acoustic analysis.** It compares phoneme
strings derived from Whisper's transcript and from the reference word - it
never touches the audio itself. That is a real limitation worth stating
plainly: it is closer in spirit to Goodness-of-Pronunciation scoring than to
naive string matching, but a true acoustic GOP score would need frame-level
posteriors from a phoneme-level acoustic model, which is out of scope here.

Loading panphon's bundled IPA feature table requires the process to be
running in Python's UTF-8 mode - see `config/ensure_utf8.py` for why, and
`manage.py` for where that is guaranteed before Django even starts.
"""

import logging

logger = logging.getLogger(__name__)


class PhoneticDistance:
    """Loaded once per process; panphon's feature table is not cheap to
    parse repeatedly."""

    _instance = None

    @classmethod
    def get(cls):
        if cls._instance is None:
            import panphon.distance

            try:
                cls._instance = cls(panphon.distance.Distance())
            except Exception as exc:
                logger.exception("Could not load the phonetic feature table")
                raise RuntimeError(
                    "Phonetic distance is unavailable: could not load panphon's "
                    "feature table. Is the process running in Python's UTF-8 "
                    "mode? See config/ensure_utf8.py."
                ) from exc
        return cls._instance

    def __init__(self, distance):
        self._distance = distance

    def similarity(self, reference_ipa, spoken_ipa):
        """0-100. 100 means the phoneme sequences are identical; lower means
        articulatorily further apart, not just textually different."""
        if not reference_ipa or not spoken_ipa:
            return 0.0

        raw = self._distance.weighted_feature_edit_distance_div_maxlen(
            reference_ipa, spoken_ipa
        )
        # The raw value is an average per-segment feature cost, unbounded
        # above in principle but rarely far past 1 for real word pairs.
        # Clamping and inverting turns it into the 0-100 "closer is better"
        # scale the rest of the app expects.
        return round(max(0.0, 1.0 - min(raw, 1.0)) * 100, 1)
