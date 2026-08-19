"""Learner profiles.

A `User` is the *login*. A `Profile` is the *learner*. One family account can
hold several children, each with their own level, points and streak - which is
what the "Pilih Profil" screen selects between.

Everything that records learning progress attaches to a Profile, never to a
User, so a sibling's practice never lands on the wrong child's record.
"""

import secrets
from datetime import timedelta

from django.conf import settings
from django.db import models
from django.utils import timezone
from django.utils.translation import gettext_lazy as _

from apps.content.models import Language

# Excludes characters a child or parent would misread aloud: 0/O, 1/I/L.
_SHARE_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
_SHARE_CODE_LENGTH = 8


def generate_share_code():
    """A code a teacher can be given to follow this learner.

    Eight characters from a 31-symbol alphabet is about 10^12 combinations -
    far too many to guess, which matters because the code grants a stranger
    read access to a child's progress.
    """
    return "".join(
        secrets.choice(_SHARE_CODE_ALPHABET) for _ in range(_SHARE_CODE_LENGTH)
    )


class Avatar(models.TextChoices):
    """Fixed illustration set. Children pick a character rather than upload a
    photo - no camera permission, no personal images stored."""

    BOY_1 = "BOY_1", _("Boy 1")
    BOY_2 = "BOY_2", _("Boy 2")
    GIRL_1 = "GIRL_1", _("Girl 1")
    GIRL_2 = "GIRL_2", _("Girl 2")
    CAT = "CAT", _("Cat")
    ELEPHANT = "ELEPHANT", _("Elephant")


class Profile(models.Model):
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="profiles",
        verbose_name=_("owner"),
    )
    name = models.CharField(_("name"), max_length=80)
    avatar = models.CharField(
        _("avatar"), max_length=16, choices=Avatar.choices, default=Avatar.BOY_1
    )

    practice_language = models.ForeignKey(
        Language,
        on_delete=models.PROTECT,
        related_name="profiles",
        verbose_name=_("practice language"),
        help_text=_(
            "The language this child practises. Separate from the app's "
            "interface language, which is a device setting."
        ),
    )

    # ---- Gamification -----------------------------------------------------
    level = models.PositiveIntegerField(_("level"), default=1)
    points = models.PositiveIntegerField(_("points"), default=0)
    streak_days = models.PositiveIntegerField(_("streak days"), default=0)
    last_practised_on = models.DateField(
        _("last practised on"), null=True, blank=True
    )

    share_code = models.CharField(
        _("share code"),
        max_length=16,
        unique=True,
        default=generate_share_code,
        help_text=_(
            "Given to a teacher so they can follow this learner. "
            "Regenerating it revokes any code already handed out."
        ),
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = _("profile")
        verbose_name_plural = _("profiles")
        ordering = ["created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["owner", "name"], name="unique_profile_name_per_owner"
            )
        ]

    def __str__(self):
        return f"{self.name} ({self.owner.email})"

    # ---- Levelling --------------------------------------------------------
    # 100 points per level, computed rather than stored as a second source of
    # truth. Deterministic and easy to explain to a child: every 100 stars is
    # a new Tahap.
    POINTS_PER_LEVEL = 100

    @property
    def level_from_points(self):
        return (self.points // self.POINTS_PER_LEVEL) + 1

    @property
    def points_into_level(self):
        return self.points % self.POINTS_PER_LEVEL

    @property
    def points_to_next_level(self):
        return self.POINTS_PER_LEVEL - self.points_into_level

    def award_points(self, amount):
        """Add points and re-derive the level. Caller saves."""
        self.points += max(0, amount)
        self.level = self.level_from_points

    def regenerate_share_code(self):
        """Issue a new code, invalidating the previous one.

        Existing teacher links are unaffected - this stops *new* links being
        made with a code that has been passed around.
        """
        self.share_code = generate_share_code()
        return self.share_code

    def register_practice(self, on_date=None):
        """Update the streak for a practice session.

        Same day: unchanged. Consecutive day: +1. Any longer gap: reset to 1.
        A gap resets rather than pauses, because a streak that survives a
        missed week would not mean anything.
        """
        today = on_date or timezone.localdate()
        previous = self.last_practised_on

        if previous == today:
            return

        if previous == today - timedelta(days=1):
            self.streak_days += 1
        else:
            self.streak_days = 1

        self.last_practised_on = today
