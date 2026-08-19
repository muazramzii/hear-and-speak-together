"""Seed bilingual learning content.

    python manage.py seed_data

Idempotent - safe to re-run. Existing rows are updated in place rather than
duplicated, so re-seeding never destroys a learner's progress.

The English and Malay content is authored separately on purpose. The Malay
list is not a translation of the English one: `kereta api` (train) is two
words in Malay, numbers and colours differ in difficulty, and a translated
word is frequently the wrong word to teach. Reference texts must be what a
Malay child would actually say.
"""

from datetime import date

from django.core.management.base import BaseCommand
from django.db import transaction

from apps.accounts.models import LanguageCode
from apps.content.models import Category, Difficulty, Language, Lesson, Word

# Date on which the Azure capability flags below were checked against
# https://learn.microsoft.com/azure/ai-services/speech-service/language-support
CAPABILITIES_VERIFIED_ON = date(2026, 8, 19)

LANGUAGES = [
    {
        "code": LanguageCode.ENGLISH,
        "name": "English",
        "locale": "en-US",
        "tts_voice": "en-US-AnaNeural",  # child voice
        "supports_pronunciation_assessment": True,
        "supports_prosody": True,
        "supports_phoneme_names": True,
        "supports_syllable_scores": True,
    },
    {
        "code": LanguageCode.MALAY,
        "name": "Bahasa Melayu",
        "locale": "ms-MY",
        "tts_voice": "ms-MY-YasminNeural",
        "supports_pronunciation_assessment": True,
        # Azure documents prosody assessment as en-US only, and phoneme
        # *names* as en-US (IPA) / en-US + zh-CN (SAPI). For ms-MY only the
        # phoneme score is returned, with no phoneme identity.
        "supports_prosody": False,
        "supports_phoneme_names": False,
        "supports_syllable_scores": False,
    },
]

# ---------------------------------------------------------------------------
# Per-word emoji, keyed by (category slug, word position).
#
# Both languages teach the same concepts in the same order, so one table
# serves both - `kucing` and `cat` are position 0 of "animals" and share 🐱.
#
# These are not decoration. A Listen round hides the word and shows four
# pictures; with no illustration and no emoji every tile renders the same
# placeholder and the exercise cannot be answered.
# ---------------------------------------------------------------------------

WORD_EMOJI = {
    "animals": ["🐱", "🐶", "🐘", "🦁", "🐯", "🐦"],
    "fruits": ["🍎", "🍌", "🍊", "🥭", "🍇"],
    "vehicles": ["🚗", "🚌", "🚂", "⛵", "✈️"],
    "home": ["🪑", "🍽️", "🚪", "🪟", "🛏️"],
    "colours": ["🔴", "🔵", "🟢", "🟡", "🟣"],
    "numbers": ["1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣"],
}

# ---------------------------------------------------------------------------
# Content. Each entry: (slug, name, icon, [(lesson title, [(word, meaning)])])
# ---------------------------------------------------------------------------

ENGLISH_CONTENT = [
    (
        "animals",
        "Animals",
        "🐾",
        [
            (
                "Animals Around Us",
                [
                    ("cat", "A small pet that says meow."),
                    ("dog", "A friendly pet that barks."),
                    ("elephant", "A very large animal with a long trunk."),
                    ("lion", "A big wild cat with a golden mane."),
                    ("tiger", "A big wild cat with orange and black stripes."),
                    ("bird", "A small animal with wings that can fly."),
                ],
            )
        ],
    ),
    (
        "fruits",
        "Fruits",
        "🍎",
        [
            (
                "Fruits We Eat",
                [
                    ("apple", "A round red or green fruit."),
                    ("banana", "A long yellow fruit."),
                    ("orange", "A round orange fruit full of juice."),
                    ("mango", "A sweet yellow fruit."),
                    ("grape", "A small round fruit that grows in bunches."),
                ],
            )
        ],
    ),
    (
        "vehicles",
        "Vehicles",
        "🚗",
        [
            (
                "Things That Move",
                [
                    ("car", "A vehicle with four wheels."),
                    ("bus", "A long vehicle that carries many people."),
                    ("train", "A long vehicle that runs on rails."),
                    ("boat", "A vehicle that travels on water."),
                    ("aeroplane", "A vehicle that flies in the sky."),
                ],
            )
        ],
    ),
    (
        "home",
        "Home",
        "🏠",
        [
            (
                "Things At Home",
                [
                    ("chair", "We sit on this."),
                    ("table", "We put things on this."),
                    ("door", "We open this to go inside."),
                    ("window", "We look outside through this."),
                    ("bed", "We sleep on this."),
                ],
            )
        ],
    ),
    (
        "colours",
        "Colours",
        "🎨",
        [
            (
                "Bright Colours",
                [
                    ("red", "The colour of a ripe tomato."),
                    ("blue", "The colour of the sky."),
                    ("green", "The colour of leaves."),
                    ("yellow", "The colour of the sun."),
                    ("purple", "The colour of a grape."),
                ],
            )
        ],
    ),
    (
        "numbers",
        "Numbers",
        "🔢",
        [
            (
                "Counting One To Five",
                [
                    ("one", "The first number."),
                    ("two", "Comes after one."),
                    ("three", "Comes after two."),
                    ("four", "Comes after three."),
                    ("five", "Comes after four."),
                ],
            )
        ],
    ),
]

MALAY_CONTENT = [
    (
        "animals",
        "Haiwan",
        "🐾",
        [
            (
                "Haiwan Di Sekeliling Kita",
                [
                    ("kucing", "Haiwan peliharaan kecil yang berbunyi miau."),
                    ("anjing", "Haiwan peliharaan yang menyalak."),
                    ("gajah", "Haiwan besar yang mempunyai belalai panjang."),
                    ("singa", "Kucing liar besar yang mempunyai rambut tebal."),
                    ("harimau", "Kucing liar besar yang berbelang hitam."),
                    ("burung", "Haiwan kecil bersayap yang boleh terbang."),
                ],
            )
        ],
    ),
    (
        "fruits",
        "Buah",
        "🍎",
        [
            (
                "Buah-buahan Yang Kita Makan",
                [
                    ("epal", "Buah bulat berwarna merah atau hijau."),
                    ("pisang", "Buah panjang berwarna kuning."),
                    ("oren", "Buah bulat berwarna oren dan berair."),
                    ("mangga", "Buah manis berwarna kuning."),
                    ("anggur", "Buah kecil bulat yang tumbuh bergugus."),
                ],
            )
        ],
    ),
    (
        "vehicles",
        "Kenderaan",
        "🚗",
        [
            (
                "Kenderaan Yang Bergerak",
                [
                    ("kereta", "Kenderaan yang mempunyai empat tayar."),
                    ("bas", "Kenderaan panjang yang membawa ramai orang."),
                    ("kereta api", "Kenderaan panjang yang bergerak atas landasan."),
                    ("bot", "Kenderaan yang bergerak di atas air."),
                    ("kapal terbang", "Kenderaan yang terbang di udara."),
                ],
            )
        ],
    ),
    (
        "home",
        "Rumah",
        "🏠",
        [
            (
                "Barang Di Rumah",
                [
                    ("kerusi", "Kita duduk di atasnya."),
                    ("meja", "Kita meletakkan barang di atasnya."),
                    ("pintu", "Kita buka untuk masuk ke dalam."),
                    ("tingkap", "Kita memandang ke luar melaluinya."),
                    ("katil", "Kita tidur di atasnya."),
                ],
            )
        ],
    ),
    (
        "colours",
        "Warna",
        "🎨",
        [
            (
                "Warna-warna Cerah",
                [
                    ("merah", "Warna buah tomato yang masak."),
                    ("biru", "Warna langit."),
                    ("hijau", "Warna daun."),
                    ("kuning", "Warna matahari."),
                    ("ungu", "Warna buah anggur."),
                ],
            )
        ],
    ),
    (
        "numbers",
        "Nombor",
        "🔢",
        [
            (
                "Mengira Satu Hingga Lima",
                [
                    ("satu", "Nombor yang pertama."),
                    ("dua", "Selepas satu."),
                    ("tiga", "Selepas dua."),
                    ("empat", "Selepas tiga."),
                    ("lima", "Selepas empat."),
                ],
            )
        ],
    ),
]


class Command(BaseCommand):
    help = "Seed bilingual languages, categories, lessons and words."

    def add_arguments(self, parser):
        parser.add_argument(
            "--reset",
            action="store_true",
            help="Delete existing content before seeding. Destroys words and "
            "therefore any attempts referencing them.",
        )

    def log(self, message, style=None):
        """Respect --verbosity so the test suite is not drowned in seed output."""
        if self.verbosity >= 1:
            self.stdout.write(style(message) if style else message)

    @transaction.atomic
    def handle(self, *args, **options):
        self.verbosity = options.get("verbosity", 1)

        if options["reset"]:
            self.log("Deleting existing content...", self.style.WARNING)
            Word.objects.all().delete()
            Lesson.objects.all().delete()
            Category.objects.all().delete()

        languages = self._seed_languages()

        totals = {"categories": 0, "lessons": 0, "words": 0}
        for code, content in (
            (LanguageCode.ENGLISH, ENGLISH_CONTENT),
            (LanguageCode.MALAY, MALAY_CONTENT),
        ):
            counts = self._seed_content(languages[code], content)
            for key in totals:
                totals[key] += counts[key]

        self._link_distractors()

        self.log(
            self.style.SUCCESS(
                "\nSeeded {languages} languages, {categories} categories, "
                "{lessons} lessons, {words} words.".format(
                    languages=len(languages), **totals
                )
            )
        )

    def _seed_languages(self):
        languages = {}
        for spec in LANGUAGES:
            language, created = Language.objects.update_or_create(
                code=spec["code"],
                defaults={
                    **{k: v for k, v in spec.items() if k != "code"},
                    "is_active": True,
                    "capabilities_verified_on": CAPABILITIES_VERIFIED_ON,
                },
            )
            languages[spec["code"]] = language
            self.log(
                f"  {'created' if created else 'updated'} language "
                f"{language.locale} (prosody="
                f"{'yes' if language.supports_prosody else 'no'})"
            )
        return languages

    def _seed_content(self, language, content):
        counts = {"categories": 0, "lessons": 0, "words": 0}

        for order, (slug, name, icon, lessons) in enumerate(content):
            category, _ = Category.objects.update_or_create(
                language=language,
                slug=slug,
                defaults={
                    "name": name,
                    "icon": icon,
                    "order": order,
                    "is_active": True,
                },
            )
            counts["categories"] += 1

            for lesson_order, (title, words) in enumerate(lessons):
                lesson, _ = Lesson.objects.update_or_create(
                    category=category,
                    title=title,
                    defaults={
                        "difficulty": Difficulty.BEGINNER,
                        "order": lesson_order,
                        "is_active": True,
                    },
                )
                counts["lessons"] += 1

                emoji_for_category = WORD_EMOJI.get(slug, [])

                for word_order, (text, meaning) in enumerate(words):
                    Word.objects.update_or_create(
                        lesson=lesson,
                        text=text,
                        defaults={
                            "meaning": meaning,
                            "order": word_order,
                            "emoji": (
                                emoji_for_category[word_order]
                                if word_order < len(emoji_for_category)
                                else ""
                            ),
                            "is_active": True,
                        },
                    )
                    counts["words"] += 1

        self.log(
            f"  {language.name}: {counts['categories']} categories, "
            f"{counts['words']} words"
        )
        return counts

    def _link_distractors(self):
        """Give every word its lesson-mates as wrong answers.

        Same-lesson words are thematically close, which makes for a genuine
        test - distinguishing a cat from a dog is a real listening task,
        whereas a cat versus the number four is not.
        """
        linked = 0
        for lesson in Lesson.objects.prefetch_related("words"):
            words = list(lesson.words.all())
            for word in words:
                others = [other for other in words if other.pk != word.pk]
                if others:
                    word.distractors.set(others)
                    linked += 1

        self.log(f"  linked distractors for {linked} words")
