"""Learning analytics.

Entirely rule-based. No machine learning and no LLM: the questions being asked
- "which words does this child keep getting wrong?" - are answered exactly by
aggregating their attempts, and a deterministic answer is one a teacher can
check and a supervisor can defend.
"""

from datetime import timedelta

from django.db.models import Avg, Count, Max, Q
from django.db.models.functions import TruncDate
from django.utils import timezone

from apps.practice.models import PracticeAttempt

from ..models import LessonProgress

# A word is "weak" when the learner has had a fair go at it and is still
# averaging below this. Two attempts is the minimum that separates a real
# difficulty from one bad recording.
WEAK_SCORE_THRESHOLD = 70
MIN_ATTEMPTS_FOR_WEAKNESS = 2

# A category is flagged when its average sits below this.
WEAK_CATEGORY_THRESHOLD = 70

# How long before a learner counts as having lapsed.
INACTIVITY_DAYS = 3


def _scored_attempts(profile):
    """Attempts that produced a score.

    Silent recordings are stored but excluded here: they say nothing about
    pronunciation ability and would drag every average down unfairly.
    """
    return PracticeAttempt.objects.filter(profile=profile).exclude(
        pronunciation_score__isnull=True, accuracy_score__isnull=True
    )


def overall_summary(profile):
    """Headline numbers for the progress screen."""
    attempts = _scored_attempts(profile)

    aggregate = attempts.aggregate(
        average=Avg("pronunciation_score"),
        sessions=Count("id"),
        words=Count("word", distinct=True),
    )

    lessons = LessonProgress.objects.filter(profile=profile)
    completed_lessons = sum(1 for record in lessons if record.is_complete)

    return {
        "average_score": (
            round(aggregate["average"]) if aggregate["average"] is not None else None
        ),
        "practice_sessions": aggregate["sessions"] or 0,
        "words_practised": aggregate["words"] or 0,
        "words_learned": _words_learned(profile),
        "lessons_started": lessons.count(),
        "lessons_completed": completed_lessons,
        "points": profile.points,
        "level": profile.level_from_points,
        "streak_days": profile.streak_days,
    }


def _words_learned(profile):
    """Distinct words whose best attempt reached the pass mark.

    Best attempt rather than average: a child who struggled and then got it
    right has learned the word, and counting the failures against them would
    punish practice.
    """
    return (
        _scored_attempts(profile)
        .values("word")
        .annotate(best=Max("pronunciation_score"))
        .filter(best__gte=75)
        .count()
    )


def weak_words(profile, limit=10):
    """Words the learner consistently struggles with.

    Ordered worst-first so the recommendation list leads with the word that
    needs the most work.
    """
    rows = (
        _scored_attempts(profile)
        .values("word", "word__text", "word__lesson_id")
        .annotate(
            average=Avg("pronunciation_score"),
            attempts=Count("id"),
            best=Max("pronunciation_score"),
        )
        .filter(
            attempts__gte=MIN_ATTEMPTS_FOR_WEAKNESS,
            average__lt=WEAK_SCORE_THRESHOLD,
        )
        .order_by("average")[:limit]
    )

    return [
        {
            "word_id": row["word"],
            "text": row["word__text"],
            "lesson_id": row["word__lesson_id"],
            "average_score": round(row["average"]),
            "best_score": round(row["best"]) if row["best"] is not None else None,
            "attempts": row["attempts"],
            "recommendation": "practise_again",
        }
        for row in rows
    ]


def category_performance(profile):
    """Average score per category, for the progress breakdown."""
    rows = (
        _scored_attempts(profile)
        .values(
            "word__lesson__category",
            "word__lesson__category__name",
            "word__lesson__category__icon",
        )
        .annotate(average=Avg("pronunciation_score"), attempts=Count("id"))
        .order_by("-average")
    )

    return [
        {
            "category_id": row["word__lesson__category"],
            "name": row["word__lesson__category__name"],
            "icon": row["word__lesson__category__icon"] or "",
            "average_score": round(row["average"]),
            "attempts": row["attempts"],
            "is_weak": row["average"] < WEAK_CATEGORY_THRESHOLD,
        }
        for row in rows
    ]


def recent_attempts(profile, limit=5):
    rows = (
        _scored_attempts(profile)
        .select_related("word")
        .order_by("-created_at")[:limit]
    )

    return [
        {
            "id": attempt.id,
            "word": attempt.reference_text,
            "score": attempt.display_score,
            "created_at": attempt.created_at,
        }
        for attempt in rows
    ]


def improvement_trend(profile, days=7):
    """Average score per day over the recent window.

    Feeds the progress chart. Days with no practice are omitted rather than
    plotted as zero - a zero would read as "scored nothing", when in fact
    nothing was attempted.
    """
    since = timezone.now() - timedelta(days=days)

    rows = (
        _scored_attempts(profile)
        .filter(created_at__gte=since)
        .annotate(day=TruncDate("created_at"))
        .values("day")
        .annotate(average=Avg("pronunciation_score"), attempts=Count("id"))
        .order_by("day")
    )

    return [
        {
            "date": row["day"],
            "average_score": round(row["average"]),
            "attempts": row["attempts"],
        }
        for row in rows
    ]


def recommendations(profile):
    """What the learner should do next.

    Simple, explainable rules rather than a model: repeat weak words, revisit
    weak categories, and nudge after a lapse.
    """
    suggestions = []

    weak = weak_words(profile, limit=3)
    if weak:
        suggestions.append(
            {
                "type": "practise_words",
                "reason": "below_target_score",
                "words": weak,
            }
        )

    weak_categories = [
        category for category in category_performance(profile) if category["is_weak"]
    ]
    if weak_categories:
        suggestions.append(
            {
                "type": "revisit_categories",
                "reason": "below_target_score",
                "categories": weak_categories[:2],
            }
        )

    if profile.last_practised_on:
        idle_days = (timezone.localdate() - profile.last_practised_on).days
        if idle_days >= INACTIVITY_DAYS:
            suggestions.append(
                {
                    "type": "gentle_reminder",
                    "reason": "inactive",
                    "days_since_practice": idle_days,
                }
            )
    else:
        suggestions.append({"type": "get_started", "reason": "no_attempts_yet"})

    return suggestions


def update_lesson_progress(profile, lesson):
    """Recalculate one lesson's progress from the attempts that exist.

    Recomputed rather than incremented: an increment that runs twice, or not
    at all, silently corrupts the record, whereas a recount is always right.
    """
    total_words = lesson.words.filter(is_active=True).count()

    attempts = _scored_attempts(profile).filter(word__lesson=lesson)

    completed = (
        attempts.values("word")
        .annotate(best=Max("pronunciation_score"))
        .filter(best__gte=75)
        .count()
    )
    aggregate = attempts.aggregate(
        average=Avg("pronunciation_score"), total=Count("id")
    )

    record, _ = LessonProgress.objects.update_or_create(
        profile=profile,
        lesson=lesson,
        defaults={
            "completed_words": completed,
            "total_words": total_words,
            "attempts_count": aggregate["total"] or 0,
            "average_score": (
                round(aggregate["average"], 1)
                if aggregate["average"] is not None
                else None
            ),
        },
    )
    return record


def lesson_progress_list(profile):
    records = (
        LessonProgress.objects.filter(profile=profile)
        .select_related("lesson", "lesson__category")
        .order_by("lesson__category__order", "lesson__order")
    )

    return [
        {
            "lesson_id": record.lesson_id,
            "title": record.lesson.title,
            "category": record.lesson.category.name,
            "completed_words": record.completed_words,
            "total_words": record.total_words,
            "completion_percentage": record.completion_percentage,
            "average_score": (
                round(record.average_score) if record.average_score is not None else None
            ),
            "attempts": record.attempts_count,
            "last_accessed": record.last_accessed,
        }
        for record in records
    ]


def has_perfect_score(profile, threshold=90):
    return _scored_attempts(profile).filter(
        Q(pronunciation_score__gte=threshold) | Q(accuracy_score__gte=threshold)
    ).exists()
