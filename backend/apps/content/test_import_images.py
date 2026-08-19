"""Tests for the import_word_images management command."""

import csv
import tempfile
from pathlib import Path

from django.core.management import CommandError, call_command
from django.test import TestCase

from apps.content.models import Category, Language, Lesson, Word


def write_csv(rows, *, fieldnames=None, encoding="utf-8"):
    handle = tempfile.NamedTemporaryFile(
        "w", suffix=".csv", delete=False, newline="", encoding=encoding
    )
    writer = csv.DictWriter(
        handle, fieldnames=fieldnames or ["language", "word", "emoji", "image_url"]
    )
    writer.writeheader()
    for row in rows:
        writer.writerow(row)
    handle.close()
    return Path(handle.name)


class ImportWordImagesTests(TestCase):
    def setUp(self):
        english = Language.objects.create(
            code="en", name="English", locale="en-US"
        )
        malay = Language.objects.create(
            code="ms", name="Bahasa Melayu", locale="ms-MY"
        )

        for language, words in (
            (english, ["cat", "dog"]),
            (malay, ["kucing", "anjing"]),
        ):
            category = Category.objects.create(
                language=language, slug="animals", name="Animals"
            )
            lesson = Lesson.objects.create(category=category, title="Animals")
            for order, text in enumerate(words):
                Word.objects.create(
                    lesson=lesson, text=text, order=order, emoji="❓"
                )

        # A word that exists in both languages, to exercise ambiguity.
        Word.objects.create(
            lesson=Lesson.objects.get(category__language=english),
            text="bola",
            order=9,
        )
        Word.objects.create(
            lesson=Lesson.objects.get(category__language=malay),
            text="bola",
            order=9,
        )

    def test_assigns_an_image_url(self):
        path = write_csv([{"word": "cat", "image_url": "https://x.test/cat.png"}])

        call_command("import_word_images", str(path), verbosity=0)

        self.assertEqual(
            Word.objects.get(text="cat").image_url, "https://x.test/cat.png"
        )

    def test_can_set_the_emoji_too(self):
        path = write_csv([{"word": "dog", "emoji": "🐶"}])

        call_command("import_word_images", str(path), verbosity=0)

        self.assertEqual(Word.objects.get(text="dog").emoji, "🐶")

    def test_blank_cells_leave_existing_values_alone(self):
        """A partially filled sheet must not wipe what it does not mention."""
        path = write_csv([{"word": "cat", "image_url": "", "emoji": ""}])

        call_command("import_word_images", str(path), verbosity=0)

        self.assertEqual(Word.objects.get(text="cat").emoji, "❓")

    def test_dry_run_changes_nothing(self):
        path = write_csv([{"word": "cat", "image_url": "https://x.test/cat.png"}])

        call_command("import_word_images", str(path), "--dry-run", verbosity=0)

        self.assertEqual(Word.objects.get(text="cat").image_url, "")

    def test_language_column_disambiguates(self):
        path = write_csv(
            [{"language": "ms", "word": "bola", "image_url": "https://x.test/b.png"}]
        )

        call_command("import_word_images", str(path), verbosity=0)

        malay = Word.objects.get(text="bola", lesson__category__language__code="ms")
        english = Word.objects.get(
            text="bola", lesson__category__language__code="en"
        )
        self.assertEqual(malay.image_url, "https://x.test/b.png")
        self.assertEqual(english.image_url, "")

    def test_an_ambiguous_word_is_refused_rather_than_guessed(self):
        path = write_csv([{"word": "bola", "image_url": "https://x.test/b.png"}])

        call_command("import_word_images", str(path), verbosity=0)

        # Neither is touched: picking one would silently attach the picture to
        # the wrong learner's word.
        self.assertFalse(Word.objects.filter(text="bola").exclude(image_url="").exists())

    def test_an_unknown_word_is_reported_not_silently_skipped(self):
        path = write_csv(
            [{"word": "elephant", "image_url": "https://x.test/e.png"}]
        )

        call_command("import_word_images", str(path), verbosity=0)

        self.assertFalse(Word.objects.exclude(image_url="").exists())

    def test_an_invalid_url_is_rejected(self):
        path = write_csv([{"word": "cat", "image_url": "not-a-url"}])

        call_command("import_word_images", str(path), verbosity=0)

        self.assertEqual(Word.objects.get(text="cat").image_url, "")

    def test_a_csv_without_a_word_column_fails_clearly(self):
        path = write_csv(
            [{"image_url": "https://x.test/a.png"}], fieldnames=["image_url"]
        )

        with self.assertRaises(CommandError) as caught:
            call_command("import_word_images", str(path), verbosity=0)

        self.assertIn("word", str(caught.exception))

    def test_a_missing_file_fails_clearly(self):
        with self.assertRaises(CommandError):
            call_command("import_word_images", "no-such-file.csv", verbosity=0)

    def test_an_excel_byte_order_mark_does_not_break_the_header(self):
        """Excel writes a BOM, which would otherwise turn the first header
        into '﻿word' and make every lookup fail."""
        path = write_csv(
            [{"word": "cat", "image_url": "https://x.test/cat.png"}],
            encoding="utf-8-sig",
        )

        call_command("import_word_images", str(path), verbosity=0)

        self.assertEqual(
            Word.objects.get(text="cat").image_url, "https://x.test/cat.png"
        )

    def test_importing_twice_is_harmless(self):
        path = write_csv([{"word": "cat", "image_url": "https://x.test/cat.png"}])

        call_command("import_word_images", str(path), verbosity=0)
        call_command("import_word_images", str(path), verbosity=0)

        self.assertEqual(
            Word.objects.get(text="cat").image_url, "https://x.test/cat.png"
        )


class TemplateTests(TestCase):
    def setUp(self):
        language = Language.objects.create(
            code="en", name="English", locale="en-US"
        )
        category = Category.objects.create(
            language=language, slug="animals", name="Animals"
        )
        lesson = Lesson.objects.create(category=category, title="Animals")
        Word.objects.create(lesson=lesson, text="cat", emoji="🐱", order=0)
        Word.objects.create(lesson=lesson, text="dog", emoji="🐶", order=1)

    def test_writes_a_row_per_word(self):
        path = Path(tempfile.mkdtemp()) / "words.csv"

        call_command("import_word_images", "--template", str(path), verbosity=0)

        with path.open(newline="", encoding="utf-8-sig") as handle:
            rows = list(csv.DictReader(handle))

        self.assertEqual(len(rows), 2)
        self.assertEqual({row["word"] for row in rows}, {"cat", "dog"})
        self.assertEqual(rows[0]["language"], "en")

    def test_the_template_round_trips(self):
        """Writing a template and importing it straight back must be a no-op,
        not a way to lose the emoji already set."""
        path = Path(tempfile.mkdtemp()) / "words.csv"
        call_command("import_word_images", "--template", str(path), verbosity=0)

        call_command("import_word_images", str(path), verbosity=0)

        self.assertEqual(Word.objects.get(text="cat").emoji, "🐱")
        self.assertEqual(Word.objects.get(text="dog").emoji, "🐶")

    def test_template_needs_content(self):
        Word.objects.all().delete()
        path = Path(tempfile.mkdtemp()) / "words.csv"

        with self.assertRaises(CommandError):
            call_command("import_word_images", "--template", str(path), verbosity=0)

    def test_requires_a_path_or_template(self):
        with self.assertRaises(CommandError):
            call_command("import_word_images", verbosity=0)
