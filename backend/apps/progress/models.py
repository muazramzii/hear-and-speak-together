"""Progress, achievements and supervisor links."""

from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.content.models import Lesson
from apps.profiles.models import Profile


class LessonProgress(models.Model):
    """A learner's standing in one lesson.

    Maintained as attempts arrive rather than recomputed on every read,
    because the dashboard queries it far more often than practice writes it.
    `completion_percentage` stays derived, so it can never disagree with the
    counts it comes from.
    """

    profile = models.ForeignKey(
        Profile, on_delete=models.CASCADE, related_name="lesson_progress"
    )
    lesson = models.ForeignKey(
        Lesson, on_delete=models.CASCADE, related_name="progress_records"
    )

    completed_words = models.PositiveIntegerField(
        _("completed words"),
        default=0,
        help_text=_("Distinct words with at least one passing attempt."),
    )
    total_words = models.PositiveIntegerField(_("total words"), default=0)
    attempts_count = models.PositiveIntegerField(_("attempts"), default=0)
    average_score = models.FloatField(_("average score"), null=True, blank=True)
    last_accessed = models.DateTimeField(_("last accessed"), auto_now=True)

    class Meta:
        verbose_name = _("lesson progress")
        verbose_name_plural = _("lesson progress")
        ordering = ["-last_accessed"]
        constraints = [
            models.UniqueConstraint(
                fields=["profile", "lesson"], name="unique_progress_per_lesson"
            )
        ]

    def __str__(self):
        return f"{self.profile.name} - {self.lesson.title}"

    @property
    def completion_percentage(self):
        if not self.total_words:
            return 0
        return round(self.completed_words / self.total_words * 100)

    @property
    def is_complete(self):
        return self.total_words > 0 and self.completed_words >= self.total_words


class AchievementCode(models.TextChoices):
    FIRST_PRACTICE = "FIRST_PRACTICE", _("First Practice")
    FIRST_PERFECT_SCORE = "FIRST_PERFECT_SCORE", _("First 90+ Score")
    TEN_WORDS = "TEN_WORDS", _("10 Words Learned")
    TWENTY_FIVE_WORDS = "TWENTY_FIVE_WORDS", _("25 Words Learned")
    FIRST_LESSON = "FIRST_LESSON", _("First Lesson Completed")
    SEVEN_DAY_STREAK = "SEVEN_DAY_STREAK", _("7 Day Streak")


class Achievement(models.Model):
    """The catalogue. Seeded, not user-created."""

    code = models.CharField(
        _("code"), max_length=32, unique=True, choices=AchievementCode.choices
    )
    name = models.CharField(_("name"), max_length=120)
    description = models.CharField(_("description"), max_length=255)
    name_ms = models.CharField(_("name (Malay)"), max_length=120, blank=True)
    description_ms = models.CharField(
        _("description (Malay)"), max_length=255, blank=True
    )
    icon = models.CharField(_("icon"), max_length=16, blank=True)
    points = models.PositiveIntegerField(_("bonus points"), default=0)
    order = models.PositiveIntegerField(_("order"), default=0)

    class Meta:
        verbose_name = _("achievement")
        verbose_name_plural = _("achievements")
        ordering = ["order", "code"]

    def __str__(self):
        return self.name

    def localised_name(self, language_code):
        return self.name_ms if language_code == "ms" and self.name_ms else self.name

    def localised_description(self, language_code):
        if language_code == "ms" and self.description_ms:
            return self.description_ms
        return self.description


class ProfileAchievement(models.Model):
    """An achievement a learner has earned."""

    profile = models.ForeignKey(
        Profile, on_delete=models.CASCADE, related_name="achievements"
    )
    achievement = models.ForeignKey(
        Achievement, on_delete=models.CASCADE, related_name="earned_by"
    )
    earned_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _("earned achievement")
        verbose_name_plural = _("earned achievements")
        ordering = ["-earned_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["profile", "achievement"],
                name="unique_achievement_per_profile",
            )
        ]

    def __str__(self):
        return f"{self.profile.name} - {self.achievement.code}"


class StudentLink(models.Model):
    """Lets a teacher follow a learner they do not own.

    Parents already own their children's profiles and need no link. This
    exists for the teacher case, where the learner belongs to a family account
    the teacher has no other access to.
    """

    supervisor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="supervised_links",
    )
    profile = models.ForeignKey(
        Profile, on_delete=models.CASCADE, related_name="supervisor_links"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _("student link")
        verbose_name_plural = _("student links")
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["supervisor", "profile"], name="unique_supervisor_link"
            )
        ]

    def __str__(self):
        return f"{self.supervisor.email} -> {self.profile.name}"
