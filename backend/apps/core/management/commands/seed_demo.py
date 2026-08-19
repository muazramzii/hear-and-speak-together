"""Create a demonstration account with realistic practice history.

    python manage.py seed_demo

Gives the progress, rewards and dashboard screens something to show, so the
app can be walked through without practising a dozen words by hand first.

Run `seed_data` and `seed_achievements` first - this command builds on the
content and badge catalogue they create.

Idempotent: re-running resets the demo learners' history rather than piling
more on top, so the figures stay predictable.
"""

import random
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from apps.accounts.models import Role
from apps.content.models import Language, Lesson
from apps.practice.models import PracticeAttempt, QuizMode, QuizSession
from apps.profiles.models import Profile
from apps.progress.models import LessonProgress, ProfileAchievement
from apps.progress.services import achievements, analytics

User = get_user_model()

DEFAULT_EMAIL = "demo@hearspeak.test"
DEFAULT_PASSWORD = "HearSpeak!2026"

# Fixed so the demo looks the same every time it is rebuilt - useful when
# screenshots or a walkthrough have to match.
RANDOM_SEED = 7

CHILDREN = [
    ("Ali", "ms", "BOY_1"),
    ("Sofia", "en", "GIRL_1"),
]


class Command(BaseCommand):
    help = "Create a demo account with sample practice history."

    def add_arguments(self, parser):
        parser.add_argument("--email", default=DEFAULT_EMAIL)
        parser.add_argument("--password", default=DEFAULT_PASSWORD)
        parser.add_argument(
            "--force",
            action="store_true",
            help="Allow running with DEBUG=False. Almost never what you want.",
        )

    def log(self, message, style=None):
        if self.verbosity >= 1:
            self.stdout.write(style(message) if style else message)

    @transaction.atomic
    def handle(self, *args, **options):
        self.verbosity = options.get("verbosity", 1)

        # This command creates an account whose password is written in the
        # source code. On a real deployment that is a way in for anyone who
        # has read the repository, so it refuses to run unless explicitly
        # forced.
        if not settings.DEBUG and not options["force"]:
            raise CommandError(
                "seed_demo creates an account with a publicly known password "
                "and is refusing to run with DEBUG=False. Pass --force only "
                "if you are certain this is not a production database."
            )

        if not Language.objects.exists() or not Lesson.objects.exists():
            raise CommandError(
                "No content found. Run `manage.py seed_data` first."
            )

        random.seed(RANDOM_SEED)

        user = self._create_account(options["email"], options["password"])

        for name, language_code, avatar in CHILDREN:
            language = Language.objects.filter(code=language_code).first()
            if language is None:
                self.log(
                    f"  skipping {name}: no {language_code} content",
                    self.style.WARNING,
                )
                continue

            profile = self._create_profile(user, name, language, avatar)
            self._build_history(profile, language)
            self._report(profile)

        self.log("")
        self.log(self.style.SUCCESS("Sign in with:"))
        self.log(f"  email    {options['email']}")
        self.log(f"  password {options['password']}")

    # -- steps ------------------------------------------------------------

    def _create_account(self, email, password):
        """A PARENT account, so the supervisor view is reachable too."""
        user = User.objects.filter(email=email).first()

        if user is None:
            user = User.objects.create_user(
                email=email, name="Demo Parent", password=password,
                role=Role.PARENT,
            )
            self.log(f"created account {email}")
        else:
            user.set_password(password)
            user.role = Role.PARENT
            user.save()
            self.log(f"reset password for {email}")

        return user

    def _create_profile(self, user, name, language, avatar):
        profile, created = Profile.objects.get_or_create(
            owner=user,
            name=name,
            defaults={"practice_language": language, "avatar": avatar},
        )

        if not created:
            # Everything derived from practice has to go, not just the
            # attempts. Leaving the earned badges behind would stop them being
            # re-awarded on the rebuild, and their bonus points would silently
            # vanish - so a second run would report a lower total than the
            # first for identical history.
            PracticeAttempt.objects.filter(profile=profile).delete()
            QuizSession.objects.filter(profile=profile).delete()
            ProfileAchievement.objects.filter(profile=profile).delete()
            LessonProgress.objects.filter(profile=profile).delete()

            profile.points = 0
            profile.level = 1
            profile.streak_days = 0
            profile.last_practised_on = None
            profile.save()

        return profile

    def _build_history(self, profile, language):
        lessons = list(
            Lesson.objects.filter(category__language=language).order_by("id")[:3]
        )
        now = timezone.now()

        for lesson_index, lesson in enumerate(lessons):
            for word_index, word in enumerate(lesson.words.all()[:5]):
                # Two deliberately weak words per learner, so the weak-word
                # analytics have something real to flag.
                weak = lesson_index == 0 and word_index < 2
                attempts = 3 if weak else random.choice([1, 2])

                for _ in range(attempts):
                    self._make_attempt(profile, word, language, weak, now)

            analytics.update_lesson_progress(profile, lesson)

        # A couple of quiz runs, so rewards reflect more than speaking.
        for lesson in lessons[:2]:
            QuizSession.objects.create(
                profile=profile,
                lesson=lesson,
                mode=random.choice([QuizMode.QUIZ, QuizMode.LISTEN]),
                correct_count=random.randint(3, 5),
                total_rounds=5,
                points_awarded=40,
            )
            profile.award_points(40)

        profile.streak_days = 5
        profile.last_practised_on = timezone.localdate()
        profile.save()

        achievements.evaluate(profile)
        profile.refresh_from_db()

    def _make_attempt(self, profile, word, language, weak, now):
        score = random.randint(38, 62) if weak else random.randint(74, 97)
        points = 10 if score >= 90 else (7 if score >= 75 else 4)

        attempt = PracticeAttempt.objects.create(
            profile=profile,
            word=word,
            language_code=language.code,
            locale=language.locale,
            reference_text=word.text,
            recognized_text=word.text if score >= 70 else "",
            accuracy_score=score,
            fluency_score=min(100, score + 4),
            completeness_score=100,
            pronunciation_score=score,
            # Null wherever the locale does not support prosody, exactly as
            # Azure behaves for ms-MY. Demo data must not imply a measurement
            # the real system cannot make.
            prosody_score=(
                min(100, score + 2) if language.supports_prosody else None
            ),
            points_awarded=points,
        )

        # Spread across recent days so the progress trend has shape.
        PracticeAttempt.objects.filter(pk=attempt.pk).update(
            created_at=now
            - timedelta(days=random.randint(0, 5), hours=random.randint(0, 12))
        )

        profile.award_points(points)

    def _report(self, profile):
        summary = analytics.overall_summary(profile)
        self.log(
            f"  {profile.name}: {summary['practice_sessions']} attempts, "
            f"average {summary['average_score']}, {profile.points} points, "
            f"streak {profile.streak_days}, share code {profile.share_code}"
        )
