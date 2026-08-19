"""Bulk-assign word illustrations from a CSV.

Write a template, fill in the URLs, import it back:

    python manage.py import_word_images --template words.csv
    python manage.py import_word_images words.csv --dry-run
    python manage.py import_word_images words.csv

Columns: `language`, `category`, `word`, `emoji`, `image_url`. Only `word` and
one of `emoji` / `image_url` are needed; `language` disambiguates a word that
exists in both languages, and `category` is written for readability and
ignored on import.

Blank cells are left alone rather than clearing the existing value, so a
partially filled sheet only updates what it fills in.
"""

import csv
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.core.validators import URLValidator
from django.core.exceptions import ValidationError
from django.db import transaction

from apps.content.models import Word

FIELDNAMES = ["language", "category", "word", "emoji", "image_url"]


class Command(BaseCommand):
    help = "Assign word images and emoji in bulk from a CSV file."

    def add_arguments(self, parser):
        parser.add_argument(
            "path",
            nargs="?",
            help="CSV to import. Omit when using --template.",
        )
        parser.add_argument(
            "--template",
            metavar="PATH",
            help="Write a CSV of every word for filling in, then exit.",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Report what would change without writing anything.",
        )

    def handle(self, *args, **options):
        self.verbosity = options.get("verbosity", 1)

        if options["template"]:
            return self._write_template(Path(options["template"]))

        if not options["path"]:
            raise CommandError(
                "Give a CSV to import, or --template PATH to create one."
            )

        self._import(Path(options["path"]), dry_run=options["dry_run"])

    # -- template ---------------------------------------------------------

    def _write_template(self, path):
        words = Word.objects.select_related(
            "lesson__category", "lesson__category__language"
        ).order_by(
            "lesson__category__language__code",
            "lesson__category__order",
            "order",
        )

        if not words.exists():
            raise CommandError("No words found. Run `manage.py seed_data` first.")

        # utf-8-sig so Excel opens the emoji column correctly rather than as
        # mojibake.
        with path.open("w", newline="", encoding="utf-8-sig") as handle:
            writer = csv.DictWriter(handle, fieldnames=FIELDNAMES)
            writer.writeheader()

            for word in words:
                writer.writerow(
                    {
                        "language": word.lesson.category.language.code,
                        "category": word.lesson.category.name,
                        "word": word.text,
                        "emoji": word.emoji,
                        "image_url": word.image_url,
                    }
                )

        self.stdout.write(
            self.style.SUCCESS(f"Wrote {words.count()} rows to {path}")
        )
        self.stdout.write(
            "Fill in the image_url column, then import it back with:\n"
            f"  manage.py import_word_images {path}"
        )

    # -- import -----------------------------------------------------------

    def _import(self, path, *, dry_run):
        if not path.exists():
            raise CommandError(f"No such file: {path}")

        validate_url = URLValidator()
        updated = 0
        skipped = 0
        problems = []

        # utf-8-sig strips the byte-order mark Excel writes, which would
        # otherwise turn the first header into "﻿language" and make every
        # lookup fail.
        with path.open(newline="", encoding="utf-8-sig") as handle:
            reader = csv.DictReader(handle)

            if reader.fieldnames is None or "word" not in reader.fieldnames:
                raise CommandError(
                    f"CSV needs a 'word' column. Found: {reader.fieldnames}"
                )

            for line_number, row in enumerate(reader, start=2):
                text = (row.get("word") or "").strip()
                if not text:
                    continue

                image_url = (row.get("image_url") or "").strip()
                emoji = (row.get("emoji") or "").strip()

                if not image_url and not emoji:
                    skipped += 1
                    continue

                if image_url:
                    try:
                        validate_url(image_url)
                    except ValidationError:
                        problems.append(
                            f"line {line_number}: '{image_url}' is not a valid URL"
                        )
                        continue

                matches = self._find(text, (row.get("language") or "").strip())

                if not matches:
                    problems.append(f"line {line_number}: no word matching '{text}'")
                    continue

                if len(matches) > 1:
                    # Never guess which learner's word was meant.
                    languages = ", ".join(
                        m.lesson.category.language.code for m in matches
                    )
                    problems.append(
                        f"line {line_number}: '{text}' matches {len(matches)} "
                        f"words ({languages}) - add a 'language' column"
                    )
                    continue

                word = matches[0]
                changed = False

                if image_url and word.image_url != image_url:
                    word.image_url = image_url
                    changed = True
                if emoji and word.emoji != emoji:
                    word.emoji = emoji
                    changed = True

                if not changed:
                    continue

                if not dry_run:
                    word.save(update_fields=["image_url", "emoji"])
                updated += 1

                if self.verbosity >= 2:
                    self.stdout.write(f"  {word.text} -> {image_url or emoji}")

        self._report(updated, skipped, problems, dry_run=dry_run)

    def _find(self, text, language_code):
        queryset = Word.objects.select_related(
            "lesson__category__language"
        ).filter(text__iexact=text)

        if language_code:
            queryset = queryset.filter(
                lesson__category__language__code__iexact=language_code
            )

        return list(queryset)

    def _report(self, updated, skipped, problems, *, dry_run):
        if dry_run:
            self.stdout.write(
                self.style.WARNING(f"Dry run: {updated} word(s) would change.")
            )
        else:
            self.stdout.write(self.style.SUCCESS(f"Updated {updated} word(s)."))

        if skipped:
            self.stdout.write(f"Skipped {skipped} row(s) with nothing to set.")

        if problems:
            # Reported rather than swallowed - a silently ignored row means an
            # illustration the author thinks is live but never appears.
            self.stdout.write(
                self.style.ERROR(f"\n{len(problems)} row(s) had problems:")
            )
            for problem in problems:
                self.stdout.write(self.style.ERROR(f"  {problem}"))
