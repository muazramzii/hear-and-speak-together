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
    """A language the app teaches, plus what Azure can actually measure for it.

    The capability flags exist because Azure AI Speech does **not** expose an
    identical feature set across locales. They are stored rather than inferred
    so the API can tell the client exactly which metrics are real, and so the
    app never displays a score that was never measured.
    """

    code = models.CharField(
        _("code"), max_length=8, unique=True, choices=LanguageCode.choices
    )
    name = models.CharField(_("name"), max_length=64)
    locale = models.CharField(
        _("locale"),
        max_length=16,
        unique=True,
        help_text=_("BCP-47 locale passed to Azure Speech, e.g. en-US."),
    )
    is_active = models.BooleanField(_("active"), default=True)

    assessment_provider = models.CharField(
        _("assessment provider"),
        max_length=16,
        choices=[
            ("default", _("Use SPEECH_PROVIDER setting")),
            ("azure", _("Azure AI Speech")),
            ("speechace", _("SpeechAce")),
            ("mock", _("Mock (no real assessment)")),
        ],
        default="default",
        help_text=_(
            "Which engine scores this language. Set per language because "
            "coverage differs: SpeechAce has no Malay, so ms-MY can only use "
            "Azure or the mock."
        ),
    )

    # ---- Azure AI Speech capabilities -------------------------------------
    # Verified against Microsoft Learn documentation; see
    # `capabilities_verified_on`. Do not edit these from guesswork - check the
    # current docs and update the date.
    supports_pronunciation_assessment = models.BooleanField(
        _("supports pronunciation assessment"), default=True
    )
    supports_prosody = models.BooleanField(
        _("supports prosody"),
        default=False,
        help_text=_("Intonation, stress and rhythm. Azure supports en-US only."),
    )
    supports_phoneme_names = models.BooleanField(
        _("supports phoneme names"),
        default=False,
        help_text=_(
            "Whether Azure returns phoneme identities (IPA) or only scores."
        ),
    )
    supports_syllable_scores = models.BooleanField(
        _("supports syllable scores"), default=False
    )
    capabilities_verified_on = models.DateField(
        _("capabilities verified on"),
        null=True,
        blank=True,
        help_text=_("When these flags were last checked against Azure's docs."),
    )

    tts_voice = models.CharField(
        _("text-to-speech voice"),
        max_length=64,
        blank=True,
        help_text=_("Azure neural voice used to pronounce words."),
    )

    class Meta:
        verbose_name = _("language")
        verbose_name_plural = _("languages")
        ordering = ["code"]

    def __str__(self):
        return f"{self.name} ({self.locale})"

    @property
    def available_metrics(self):
        """The score names that are genuinely measurable for this locale.

        The practice API reports this so the client can render only the
        metrics that exist. Accuracy, fluency and completeness are returned by
        every supported locale; prosody is the locale-dependent one.
        """
        metrics = ["accuracy", "fluency", "completeness", "pronunciation"]
        if self.supports_prosody:
            metrics.append("prosody")
        return metrics


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

    `text` is the reference text sent to Azure for scripted pronunciation
    assessment, so it must be the word exactly as it should be spoken.
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
