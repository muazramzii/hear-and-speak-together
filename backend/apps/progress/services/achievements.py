"""Awarding achievements.

Each rule is a plain predicate over data that already exists, so an award can
always be explained - and re-running the check never double-awards, because
the join table is uniquely constrained.
"""

import logging

from django.db import IntegrityError, transaction

from ..models import Achievement, AchievementCode, ProfileAchievement
from . import analytics

logger = logging.getLogger(__name__)


def _rules(profile, summary):
    """code -> whether the learner has earned it."""
    return {
        AchievementCode.FIRST_PRACTICE: summary["practice_sessions"] >= 1,
        AchievementCode.FIRST_PERFECT_SCORE: analytics.has_perfect_score(profile),
        AchievementCode.TEN_WORDS: summary["words_learned"] >= 10,
        AchievementCode.TWENTY_FIVE_WORDS: summary["words_learned"] >= 25,
        AchievementCode.FIRST_LESSON: summary["lessons_completed"] >= 1,
        AchievementCode.SEVEN_DAY_STREAK: profile.streak_days >= 7,
    }


def evaluate(profile):
    """Award anything newly earned. Returns the achievements granted now.

    Safe to call after every attempt: already-held achievements are filtered
    out first, and the unique constraint catches anything that slips through a
    race.
    """
    summary = analytics.overall_summary(profile)
    earned_codes = set(
        ProfileAchievement.objects.filter(profile=profile).values_list(
            "achievement__code", flat=True
        )
    )

    newly_earned = []
    for code, qualifies in _rules(profile, summary).items():
        if not qualifies or code in earned_codes:
            continue

        achievement = Achievement.objects.filter(code=code).first()
        if achievement is None:
            # The catalogue is seeded; a missing row is a setup problem, not a
            # reason to fail a practice attempt.
            logger.warning("Achievement %s is not in the catalogue", code)
            continue

        try:
            with transaction.atomic():
                ProfileAchievement.objects.create(
                    profile=profile, achievement=achievement
                )
        except IntegrityError:
            continue  # awarded concurrently; nothing to do

        newly_earned.append(achievement)

        if achievement.points:
            profile.award_points(achievement.points)

    if newly_earned:
        profile.save(update_fields=["points", "level", "updated_at"])

    return newly_earned


def earned_list(profile, language_code="en"):
    """Every achievement, marked as earned or not.

    Locked ones are included on purpose: showing a child what is still ahead
    is the point of a rewards screen.
    """
    earned = {
        item.achievement_id: item.earned_at
        for item in ProfileAchievement.objects.filter(profile=profile)
    }

    return [
        {
            "code": achievement.code,
            "name": achievement.localised_name(language_code),
            "description": achievement.localised_description(language_code),
            "icon": achievement.icon,
            "points": achievement.points,
            "earned": achievement.id in earned,
            "earned_at": earned.get(achievement.id),
        }
        for achievement in Achievement.objects.all()
    ]
