"""Bilingual learning content: languages, categories, lessons and words.

Content is authored per language rather than translated at runtime. The Malay
"Haiwan" lesson holds real Malay words, not machine translations of the English
list, because a translated word is often the wrong word pedagogically and gives
the speech assessor a reference text nobody actually says.
"""

from django.core.exceptions import ValidationError
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.accounts.models import LanguageCode


class Language(models.Model):
    """A language the app teaches.

    Pronunciation assessment is self-hosted (Whisper plus the pronunciation
    engine in `apps.practice.services.pronunciation`) and treats every
    supported language the same way, so - unlike the Azure-backed version of
    this model - there are no per-locale capability flags here. The
    supported-language set lives with the engine itself
    (`_SUPPORTED_LANGUAGES` in `evaluation.py`), since that is what actually
    has to know which G2P table exists for which code.
    """

    code = models.CharField(
        _("code"), max_length=8, unique=True, choices=LanguageCode.choices
    )
    name = models.CharField(_("name"), max_length=64)
    locale = models.CharField(
        _("locale"),
        max_length=16,
        unique=True,
        help_text=_("BCP-47 locale, e.g. en-US. Used for text-to-speech."),
    )
    is_active = models.BooleanField(_("active"), default=True)

    tts_voice = models.CharField(
        _("text-to-speech voice"),
        max_length=64,
        blank=True,
        help_text=_("Voice identifier used when reading a word aloud."),
    )

    class Meta:
        verbose_name = _("language")
        verbose_name_plural = _("languages")
        ordering = ["code"]

    def __str__(self):
        return f"{self.name} ({self.locale})"


class Category(models.Model):
    """A themed group of lessons, e.g. Animals / Haiwan.

    Categories belong to exactly one language. `slug` is the stable
    cross-language key, so the English "animals" and the Malay "animals" can be
    recognised as the same theme without sharing a row.
    """

    language = models.ForeignKey(
        Language, on_delete=models.CASCADE, related_name="categories"
    )
    slug = models.SlugField(_("slug"), max_length=64)
    name = models.CharField(_("name"), max_length=120)
    description = models.TextField(_("description"), blank=True)
    icon = models.CharField(
        _("icon"),
        max_length=16,
        blank=True,
        help_text=_("Emoji shown on the category chip."),
    )
    image_url = models.URLField(_("image URL"), blank=True)
    order = models.PositiveIntegerField(_("order"), default=0)
    is_active = models.BooleanField(_("active"), default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _("category")
        verbose_name_plural = _("categories")
        ordering = ["language__code", "order", "name"]
        constraints = [
            models.UniqueConstraint(
                fields=["language", "slug"], name="unique_category_slug_per_language"
            )
        ]

    def __str__(self):
        return f"{self.name} [{self.language.code}]"


class Difficulty(models.TextChoices):
    BEGINNER = "BEGINNER", _("Beginner")
    INTERMEDIATE = "INTERMEDIATE", _("Intermediate")


class Lesson(models.Model):
    category = models.ForeignKey(
        Category, on_delete=models.CASCADE, related_name="lessons"
    )
    title = models.CharField(_("title"), max_length=160)
    description = models.TextField(_("description"), blank=True)
    difficulty = models.CharField(
        _("difficulty"),
        max_length=16,
        choices=Difficulty.choices,
        default=Difficulty.BEGINNER,
    )
    image_url = models.URLField(_("image URL"), blank=True)
    order = models.PositiveIntegerField(_("order"), default=0)
    is_active = models.BooleanField(_("active"), default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _("lesson")
        verbose_name_plural = _("lessons")
        ordering = ["category", "order", "title"]

    def __str__(self):
        return self.title

    @property
    def language(self):
        return self.category.language

    # `word_count` is deliberately NOT a property here. The API annotates it
    # onto the queryset to avoid an N+1, and Django cannot assign an
    # annotation over a property that has no setter.


class Word(models.Model):
    """A single vocabulary item - the unit the child actually practises.

    `text` is the reference text the pronunciation engine scores a recording
    against, so it must be the word exactly as it should be spoken.
    """

    lesson = models.ForeignKey(
        Lesson, on_delete=models.CASCADE, related_name="words"
    )
    text = models.CharField(
        _("word"),
        max_length=120,
        help_text=_("Reference text for pronunciation assessment."),
    )
    meaning = models.TextField(_("meaning"), blank=True)
    example_sentence = models.TextField(_("example sentence"), blank=True)
    image_url = models.URLField(_("image URL"), blank=True)
    emoji = models.CharField(
        _("emoji"),
        max_length=8,
        blank=True,
        help_text=_(
            "Shown when no illustration is available. Without it a Listen "
            "round is unplayable, because the word is hidden and every "
            "option would look identical."
        ),
    )
    audio_url = models.URLField(
        _("audio URL"),
        blank=True,
        help_text=_("Optional pre-recorded audio. Falls back to TTS when empty."),
    )
    order = models.PositiveIntegerField(_("order"), default=0)
    is_active = models.BooleanField(_("active"), default=True)

    # Wrong answers for the Listen and Quiz modes. Modelled as relations to
    # real words rather than free text, so every option is genuine vocabulary
    # in the correct language and comes with its own image.
    distractors = models.ManyToManyField(
        "self",
        symmetrical=False,
        blank=True,
        related_name="distractor_for",
        verbose_name=_("distractors"),
        help_text=_("Wrong options offered alongside this word in quizzes."),
    )

    class Meta:
        verbose_name = _("word")
        verbose_name_plural = _("words")
        ordering = ["lesson", "order", "text"]
        constraints = [
            models.UniqueConstraint(
                fields=["lesson", "text"], name="unique_word_per_lesson"
            )
        ]

    def __str__(self):
        return self.text

    @property
    def language(self):
        return self.lesson.category.language

    def clean(self):
        # A word cannot be its own wrong answer. Only checkable once saved,
        # since M2M needs a primary key.
        if self.pk and self.distractors.filter(pk=self.pk).exists():
            raise ValidationError(
                {"distractors": _("A word cannot be its own distractor.")}
            )

    def quiz_options(self, count=4):
        """Return this word plus wrong options, for a multiple-choice round.

        Explicit distractors are preferred because they are hand-picked to be
        plausibly confusable. When too few are set, the gap is filled from the
        same category so a round can always be built - falling back to the
        lesson alone would fail for short lessons.
        """
        options = list(self.distractors.filter(is_active=True)[: count - 1])

        if len(options) < count - 1:
            exclude_ids = [self.pk] + [option.pk for option in options]
            filler = (
                Word.objects.filter(
                    lesson__category=self.lesson.category, is_active=True
                )
                .exclude(pk__in=exclude_ids)
                .order_by("?")[: count - 1 - len(options)]
            )
            options.extend(filler)

        return [self] + options
