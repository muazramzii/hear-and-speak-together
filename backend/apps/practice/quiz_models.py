"""Results from the Listen and Quiz modes.

Kept separate from `PracticeAttempt`, which records a *spoken* attempt scored
by Azure. A quiz round is a tap on a picture: no audio, no pronunciation
score. Storing both in one table would mean a column that is meaningless for
half the rows, and would corrupt the pronunciation averages the analytics are
built on.
"""

from django.db import models
from django.utils.translation import gettext_lazy as _

from apps.content.models import Lesson
from apps.profiles.models import Profile


class QuizMode(models.TextChoices):
    LISTEN = "LISTEN", _("Listen")
    QUIZ = "QUIZ", _("Quiz")


class QuizSession(models.Model):
    """One completed run of multiple-choice rounds."""

    profile = models.ForeignKey(
        Profile, on_delete=models.CASCADE, related_name="quiz_sessions"
    )
    lesson = models.ForeignKey(
        Lesson, on_delete=models.CASCADE, related_name="quiz_sessions"
    )
    mode = models.CharField(_("mode"), max_length=16, choices=QuizMode.choices)

    correct_count = models.PositiveIntegerField(_("correct answers"), default=0)
    total_rounds = models.PositiveIntegerField(_("total rounds"), default=0)
    points_awarded = models.PositiveIntegerField(_("points awarded"), default=0)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = _("quiz session")
        verbose_name_plural = _("quiz sessions")
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["profile", "-created_at"])]

    def __str__(self):
        return (
            f"{self.profile.name} - {self.lesson.title} "
            f"({self.correct_count}/{self.total_rounds})"
        )

    @property
    def accuracy_percentage(self):
        if not self.total_rounds:
            return 0
        return round(self.correct_count / self.total_rounds * 100)
