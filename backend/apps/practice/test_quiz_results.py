"""Phase 7 tests: quiz result persistence."""

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APITestCase

from apps.content.models import Category, Language, Lesson, Word
from apps.profiles.models import Profile

from .quiz_models import QuizMode, QuizSession

User = get_user_model()


def build_world(word_count=6):
    language = Language.objects.create(
        code="en", name="English", locale="en-US"
    )
    category = Category.objects.create(
        language=language, slug="animals", name="Animals"
    )
    lesson = Lesson.objects.create(category=category, title="Animals")
    for i in range(word_count):
        Word.objects.create(lesson=lesson, text=f"word{i}", order=i)
    return language, lesson


class QuizSessionModelTests(TestCase):
    def setUp(self):
        self.language, self.lesson = build_world()
        user = User.objects.create_user(
            email="p@example.com", name="P", password="TeaCup!2026"
        )
        self.profile = Profile.objects.create(
            owner=user, name="Ali", practice_language=self.language
        )

    def test_accuracy_percentage(self):
        session = QuizSession.objects.create(
            profile=self.profile,
            lesson=self.lesson,
            mode=QuizMode.QUIZ,
            correct_count=8,
            total_rounds=10,
        )

        self.assertEqual(session.accuracy_percentage, 80)

    def test_an_empty_session_does_not_divide_by_zero(self):
        session = QuizSession.objects.create(
            profile=self.profile, lesson=self.lesson, mode=QuizMode.LISTEN
        )

        self.assertEqual(session.accuracy_percentage, 0)


class QuizResultAPITests(APITestCase):
    def setUp(self):
        call_command("seed_achievements", verbosity=0)
        self.language, self.lesson = build_world()
        self.user = User.objects.create_user(
            email="p@example.com", name="P", password="TeaCup!2026"
        )
        self.other = User.objects.create_user(
            email="o@example.com", name="O", password="TeaCup!2026"
        )
        self.profile = Profile.objects.create(
            owner=self.user, name="Ali", practice_language=self.language
        )
        self.authenticate(self.user)

    def authenticate(self, user):
        login = self.client.post(
            reverse("accounts:login"),
            {"email": user.email, "password": "TeaCup!2026"},
            format="json",
        )
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {login.json()['access']}"
        )

    def submit(self, **overrides):
        payload = {
            "profile_id": self.profile.id,
            "lesson_id": self.lesson.id,
            "mode": QuizMode.QUIZ,
            "correct_count": 4,
            "total_rounds": 5,
        }
        payload.update(overrides)
        return self.client.post(
            "/api/practice/quiz-result/", payload, format="json"
        )

    def test_requires_authentication(self):
        self.client.credentials()

        self.assertEqual(self.submit().status_code, 401)

    def test_a_session_is_recorded_and_points_awarded(self):
        response = self.submit()

        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertEqual(body["correct_count"], 4)
        self.assertEqual(body["accuracy_percentage"], 80)
        self.assertEqual(body["points_awarded"], 40)

        self.profile.refresh_from_db()
        # 40 for the quiz, plus the 5-point First Practice bonus this run
        # unlocks. `points_awarded` reports the quiz alone; the profile total
        # includes achievement bonuses.
        self.assertEqual(self.profile.points, 45)

    def test_practising_starts_a_streak(self):
        self.submit()

        self.profile.refresh_from_db()
        self.assertEqual(self.profile.streak_days, 1)

    def test_listen_mode_is_recorded_separately(self):
        self.submit(mode=QuizMode.LISTEN)

        self.assertTrue(
            QuizSession.objects.filter(mode=QuizMode.LISTEN).exists()
        )

    def test_more_correct_than_rounds_is_rejected(self):
        """A client claiming 10/5 is broken or forging points."""
        response = self.submit(correct_count=10, total_rounds=5)

        self.assertEqual(response.status_code, 400)
        self.assertEqual(QuizSession.objects.count(), 0)

    def test_more_rounds_than_the_lesson_has_words_is_rejected(self):
        # Bounds how far a forged request could inflate a score.
        response = self.submit(correct_count=50, total_rounds=50)

        self.assertEqual(response.status_code, 400)
        self.assertEqual(QuizSession.objects.count(), 0)

    def test_zero_rounds_is_rejected(self):
        response = self.submit(correct_count=0, total_rounds=0)

        self.assertEqual(response.status_code, 400)

    def test_cannot_score_against_another_users_child(self):
        theirs = Profile.objects.create(
            owner=self.other, name="Hidden", practice_language=self.language
        )

        response = self.submit(profile_id=theirs.id)

        self.assertEqual(response.status_code, 400)
        self.assertFalse(QuizSession.objects.filter(profile=theirs).exists())

    def test_unknown_lesson_is_rejected(self):
        response = self.submit(lesson_id=999999)

        self.assertEqual(response.status_code, 400)

    def test_a_perfect_run_can_unlock_an_achievement(self):
        body = self.submit(correct_count=5, total_rounds=5).json()

        codes = [item["code"] for item in body["new_achievements"]]
        self.assertIn("FIRST_PRACTICE", codes)
