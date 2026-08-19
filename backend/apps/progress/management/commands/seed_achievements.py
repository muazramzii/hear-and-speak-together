"""Seed the achievement catalogue.

    python manage.py seed_achievements

Idempotent. Names are stored in both languages so a Malay learner is
congratulated in Malay.
"""

from django.core.management.base import BaseCommand

from apps.progress.models import Achievement, AchievementCode

ACHIEVEMENTS = [
    {
        "code": AchievementCode.FIRST_PRACTICE,
        "name": "First Practice",
        "name_ms": "Latihan Pertama",
        "description": "Great start!",
        "description_ms": "Permulaan yang hebat!",
        "icon": "🌟",
        "points": 5,
        "order": 1,
    },
    {
        "code": AchievementCode.FIRST_PERFECT_SCORE,
        "name": "Excellent Pronunciation",
        "name_ms": "Sebutan Cemerlang",
        "description": "You scored 90 or more!",
        "description_ms": "Anda mendapat skor 90 atau lebih!",
        "icon": "🏅",
        "points": 20,
        "order": 2,
    },
    {
        "code": AchievementCode.FIRST_LESSON,
        "name": "Lesson Complete",
        "name_ms": "Pelajaran Selesai",
        "description": "You finished a whole lesson!",
        "description_ms": "Anda menamatkan satu pelajaran penuh!",
        "icon": "📘",
        "points": 25,
        "order": 3,
    },
    {
        "code": AchievementCode.TEN_WORDS,
        "name": "Fast Learner",
        "name_ms": "Pelajar Pantas",
        "description": "You have learned 10 words!",
        "description_ms": "Anda telah mempelajari 10 perkataan!",
        "icon": "⚡",
        "points": 30,
        "order": 4,
    },
    {
        "code": AchievementCode.SEVEN_DAY_STREAK,
        "name": "Fantastic Consistency",
        "name_ms": "Konsisten Hebat",
        "description": "You practised seven days in a row!",
        "description_ms": "Anda berlatih tujuh hari berturut-turut!",
        "icon": "🔥",
        "points": 50,
        "order": 5,
    },
    {
        "code": AchievementCode.TWENTY_FIVE_WORDS,
        "name": "Word Master",
        "name_ms": "Juara Perkataan",
        "description": "You have learned 25 words!",
        "description_ms": "Anda telah mempelajari 25 perkataan!",
        "icon": "🏆",
        "points": 75,
        "order": 6,
    },
]


class Command(BaseCommand):
    help = "Seed the achievement catalogue."

    def handle(self, *args, **options):
        verbosity = options.get("verbosity", 1)
        created_count = 0

        for spec in ACHIEVEMENTS:
            _, created = Achievement.objects.update_or_create(
                code=spec["code"],
                defaults={k: v for k, v in spec.items() if k != "code"},
            )
            created_count += int(created)

        if verbosity >= 1:
            self.stdout.write(
                self.style.SUCCESS(
                    f"Seeded {len(ACHIEVEMENTS)} achievements "
                    f"({created_count} new)."
                )
            )
