"""Phase 6 tests: analytics, achievements and supervisor access."""

from datetime import timedelta

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APITestCase

from apps.accounts.models import Role
from apps.content.models import Category, Language, Lesson, Word
from apps.practice.models import PracticeAttempt
from apps.profiles.models import Profile

from .models import Achievement, AchievementCode, ProfileAchievement, StudentLink
from .services import achievements as achievement_service
from .services import analytics

User = get_user_model()


def build_world(word_count=4):
    language = Language.objects.create(
        code="en", name="English", locale="en-US", supports_prosody=True
    )
    category = Category.objects.create(
        language=language, slug="animals", name="Animals", icon="🐾"
    )
    lesson = Lesson.objects.create(category=category, title="Animals")
    words = [
        Word.objects.create(lesson=lesson, text=f"word{i}", order=i)
        for i in range(word_count)
    ]
    return language, lesson, words


def attempt(profile, word, score, *, when=None):
    record = PracticeAttempt.objects.create(
        profile=profile,
        word=word,
        language_code="en",
        locale="en-US",
        reference_text=word.text,
        recognized_text=word.text,
        pronunciation_score=score,
        accuracy_score=score,
    )
    if when is not None:
        PracticeAttempt.objects.filter(pk=record.pk).update(created_at=when)
        record.refresh_from_db()
    return record


class AnalyticsTests(TestCase):
    def setUp(self):
        self.language, self.lesson, self.words = build_world()
        user = User.objects.create_user(
            email="p@example.com", name="P", password="TeaCup!2026"
        )
        self.profile = Profile.objects.create(
            owner=user, name="Ali", practice_language=self.language
        )

    def test_summary_is_empty_for_a_new_learner(self):
        summary = analytics.overall_summary(self.profile)

        self.assertIsNone(summary["average_score"])
        self.assertEqual(summary["practice_sessions"], 0)
        self.assertEqual(summary["words_learned"], 0)

    def test_summary_counts_sessions_and_averages(self):
        attempt(self.profile, self.words[0], 80)
        attempt(self.profile, self.words[1], 90)

        summary = analytics.overall_summary(self.profile)

        self.assertEqual(summary["practice_sessions"], 2)
        self.assertEqual(summary["average_score"], 85)
        self.assertEqual(summary["words_practised"], 2)

    def test_quiz_sessions_count_as_activity_but_not_as_pronunciation(self):
        """A tap on a picture says nothing about how a child sounds, so it
        must not move the score average - but it is still practice."""
        from apps.practice.models import QuizMode, QuizSession

        attempt(self.profile, self.words[0], 90)
        QuizSession.objects.create(
            profile=self.profile,
            lesson=self.lesson,
            mode=QuizMode.QUIZ,
            correct_count=4,
            total_rounds=5,
        )

        summary = analytics.overall_summary(self.profile)

        self.assertEqual(summary["average_score"], 90)
        self.assertEqual(summary["practice_sessions"], 1)
        self.assertEqual(summary["quiz_sessions"], 1)
        self.assertEqual(summary["total_sessions"], 2)

    def test_words_learned_uses_the_best_attempt_not_the_average(self):
        """A child who struggled then succeeded has learned the word."""
        attempt(self.profile, self.words[0], 40)
        attempt(self.profile, self.words[0], 88)

        self.assertEqual(analytics.overall_summary(self.profile)["words_learned"], 1)

    def test_silent_attempts_do_not_drag_the_average_down(self):
        attempt(self.profile, self.words[0], 90)
        # A recording where nothing was heard: stored, but unscored.
        PracticeAttempt.objects.create(
            profile=self.profile,
            word=self.words[1],
            language_code="en",
            locale="en-US",
            reference_text=self.words[1].text,
        )

        self.assertEqual(analytics.overall_summary(self.profile)["average_score"], 90)

    def test_weak_words_need_repeated_evidence(self):
        # One bad attempt is a bad recording, not a weakness.
        attempt(self.profile, self.words[0], 40)

        self.assertEqual(analytics.weak_words(self.profile), [])

        attempt(self.profile, self.words[0], 44)
        weak = analytics.weak_words(self.profile)

        self.assertEqual(len(weak), 1)
        self.assertEqual(weak[0]["text"], "word0")
        # (40 + 44) / 2, chosen to land on a whole number so the assertion
        # does not depend on the rounding mode.
        self.assertEqual(weak[0]["average_score"], 42)
        self.assertEqual(weak[0]["best_score"], 44)
        self.assertEqual(weak[0]["attempts"], 2)

    def test_strong_words_are_never_flagged_as_weak(self):
        attempt(self.profile, self.words[0], 88)
        attempt(self.profile, self.words[0], 92)

        self.assertEqual(analytics.weak_words(self.profile), [])

    def test_weak_words_are_ordered_worst_first(self):
        for score in (30, 35):
            attempt(self.profile, self.words[0], score)
        for score in (60, 65):
            attempt(self.profile, self.words[1], score)

        weak = analytics.weak_words(self.profile)

        self.assertEqual([item["text"] for item in weak], ["word0", "word1"])

    def test_category_performance_flags_a_weak_category(self):
        attempt(self.profile, self.words[0], 50)
        attempt(self.profile, self.words[1], 55)

        categories = analytics.category_performance(self.profile)

        self.assertEqual(len(categories), 1)
        self.assertEqual(categories[0]["name"], "Animals")
        self.assertTrue(categories[0]["is_weak"])

    def test_lesson_progress_is_recomputed_from_attempts(self):
        attempt(self.profile, self.words[0], 90)
        attempt(self.profile, self.words[1], 85)

        record = analytics.update_lesson_progress(self.profile, self.lesson)

        self.assertEqual(record.completed_words, 2)
        self.assertEqual(record.total_words, 4)
        self.assertEqual(record.completion_percentage, 50)
        self.assertFalse(record.is_complete)

    def test_recomputing_progress_is_idempotent(self):
        attempt(self.profile, self.words[0], 90)

        analytics.update_lesson_progress(self.profile, self.lesson)
        record = analytics.update_lesson_progress(self.profile, self.lesson)

        self.assertEqual(record.completed_words, 1)
        self.assertEqual(record.attempts_count, 1)

    def test_a_finished_lesson_reports_complete(self):
        for word in self.words:
            attempt(self.profile, word, 90)

        record = analytics.update_lesson_progress(self.profile, self.lesson)

        self.assertTrue(record.is_complete)
        self.assertEqual(record.completion_percentage, 100)

    def test_trend_omits_days_with_no_practice(self):
        now = timezone.now()
        attempt(self.profile, self.words[0], 80, when=now)
        attempt(self.profile, self.words[1], 90, when=now - timedelta(days=2))

        trend = analytics.improvement_trend(self.profile, days=7)

        # Two days practised, so exactly two points - a gap day must not be
        # plotted as a zero score.
        self.assertEqual(len(trend), 2)


class RecommendationTests(TestCase):
    def setUp(self):
        self.language, self.lesson, self.words = build_world()
        user = User.objects.create_user(
            email="p@example.com", name="P", password="TeaCup!2026"
        )
        self.profile = Profile.objects.create(
            owner=user, name="Ali", practice_language=self.language
        )

    def test_a_brand_new_learner_is_told_to_get_started(self):
        types = [item["type"] for item in analytics.recommendations(self.profile)]

        self.assertIn("get_started", types)

    def test_weak_words_are_recommended_for_repeat_practice(self):
        attempt(self.profile, self.words[0], 40)
        attempt(self.profile, self.words[0], 45)
        self.profile.register_practice()
        self.profile.save()

        suggestions = analytics.recommendations(self.profile)
        by_type = {item["type"]: item for item in suggestions}

        self.assertIn("practise_words", by_type)
        self.assertEqual(by_type["practise_words"]["words"][0]["text"], "word0")

    def test_a_lapsed_learner_gets_a_gentle_reminder(self):
        attempt(self.profile, self.words[0], 90)
        self.profile.last_practised_on = timezone.localdate() - timedelta(days=5)
        self.profile.save()

        types = [item["type"] for item in analytics.recommendations(self.profile)]

        self.assertIn("gentle_reminder", types)

    def test_a_learner_who_practised_today_is_not_nagged(self):
        attempt(self.profile, self.words[0], 90)
        self.profile.register_practice()
        self.profile.save()

        types = [item["type"] for item in analytics.recommendations(self.profile)]

        self.assertNotIn("gentle_reminder", types)


class AchievementTests(TestCase):
    def setUp(self):
        call_command("seed_achievements", verbosity=0)
        self.language, self.lesson, self.words = build_world(word_count=30)
        user = User.objects.create_user(
            email="p@example.com", name="P", password="TeaCup!2026"
        )
        self.profile = Profile.objects.create(
            owner=user, name="Ali", practice_language=self.language
        )

    def codes(self, earned):
        return {item.code for item in earned}

    def test_seeding_is_idempotent(self):
        call_command("seed_achievements", verbosity=0)

        self.assertEqual(Achievement.objects.count(), 6)

    def test_first_practice_is_awarded(self):
        attempt(self.profile, self.words[0], 60)

        earned = achievement_service.evaluate(self.profile)

        self.assertIn(AchievementCode.FIRST_PRACTICE, self.codes(earned))

    def test_a_high_score_awards_the_pronunciation_badge(self):
        attempt(self.profile, self.words[0], 95)

        earned = achievement_service.evaluate(self.profile)

        self.assertIn(AchievementCode.FIRST_PERFECT_SCORE, self.codes(earned))

    def test_a_low_score_does_not_award_the_pronunciation_badge(self):
        attempt(self.profile, self.words[0], 60)

        earned = achievement_service.evaluate(self.profile)

        self.assertNotIn(AchievementCode.FIRST_PERFECT_SCORE, self.codes(earned))

    def test_ten_words_is_awarded_once_ten_are_learned(self):
        for word in self.words[:10]:
            attempt(self.profile, word, 85)

        earned = achievement_service.evaluate(self.profile)

        self.assertIn(AchievementCode.TEN_WORDS, self.codes(earned))

    def test_a_streak_awards_the_consistency_badge(self):
        attempt(self.profile, self.words[0], 80)
        self.profile.streak_days = 7
        self.profile.save()

        earned = achievement_service.evaluate(self.profile)

        self.assertIn(AchievementCode.SEVEN_DAY_STREAK, self.codes(earned))

    def test_an_achievement_is_never_awarded_twice(self):
        attempt(self.profile, self.words[0], 95)

        first = achievement_service.evaluate(self.profile)
        second = achievement_service.evaluate(self.profile)

        self.assertGreater(len(first), 0)
        self.assertEqual(second, [])
        self.assertEqual(
            ProfileAchievement.objects.filter(profile=self.profile).count(),
            len(first),
        )

    def test_bonus_points_are_credited(self):
        attempt(self.profile, self.words[0], 95)

        achievement_service.evaluate(self.profile)

        self.profile.refresh_from_db()
        # First Practice (5) + Excellent Pronunciation (20)
        self.assertEqual(self.profile.points, 25)

    def test_the_list_includes_locked_achievements(self):
        items = achievement_service.earned_list(self.profile)

        self.assertEqual(len(items), 6)
        self.assertTrue(all(item["earned"] is False for item in items))

    def test_names_are_localised_for_malay_learners(self):
        items = achievement_service.earned_list(self.profile, language_code="ms")
        names = {item["name"] for item in items}

        self.assertIn("Latihan Pertama", names)


class ProgressAPITests(APITestCase):
    def setUp(self):
        call_command("seed_achievements", verbosity=0)
        self.language, self.lesson, self.words = build_world()
        self.user = User.objects.create_user(
            email="p@example.com", name="P", password="TeaCup!2026"
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

    def test_progress_requires_authentication(self):
        self.client.credentials()

        self.assertEqual(self.client.get("/api/progress/").status_code, 401)

    def test_progress_returns_all_sections(self):
        attempt(self.profile, self.words[0], 85)
        analytics.update_lesson_progress(self.profile, self.lesson)

        body = self.client.get("/api/progress/").json()

        for key in (
            "summary",
            "lessons",
            "categories",
            "weak_words",
            "recent_attempts",
            "trend",
        ):
            self.assertIn(key, body)
        self.assertEqual(body["summary"]["practice_sessions"], 1)

    def test_lesson_progress_for_an_unstarted_lesson_is_not_an_error(self):
        body = self.client.get(f"/api/progress/{self.lesson.id}/").json()

        self.assertFalse(body["started"])
        self.assertEqual(body["completion_percentage"], 0)

    def test_dashboard_includes_recommendations(self):
        body = self.client.get("/api/dashboard/").json()

        self.assertIn("recommendations", body)
        self.assertIn("summary", body)

    def test_achievements_endpoint_lists_the_catalogue(self):
        body = self.client.get("/api/achievements/").json()

        self.assertEqual(len(body), 6)

    def test_recommendations_endpoint(self):
        body = self.client.get("/api/recommendations/").json()

        self.assertIsInstance(body, list)


class SupervisorAccessTests(APITestCase):
    """A supervisor must only ever see learners they are entitled to."""

    def setUp(self):
        self.language, self.lesson, self.words = build_world()

        self.parent = User.objects.create_user(
            email="parent@example.com",
            name="Parent",
            password="TeaCup!2026",
            role=Role.PARENT,
        )
        self.teacher = User.objects.create_user(
            email="teacher@example.com",
            name="Teacher",
            password="TeaCup!2026",
            role=Role.TEACHER,
        )
        self.student_account = User.objects.create_user(
            email="student@example.com",
            name="Student",
            password="TeaCup!2026",
            role=Role.STUDENT,
        )
        self.stranger = User.objects.create_user(
            email="stranger@example.com",
            name="Stranger",
            password="TeaCup!2026",
            role=Role.PARENT,
        )

        self.own_child = Profile.objects.create(
            owner=self.parent, name="Ali", practice_language=self.language
        )
        self.other_child = Profile.objects.create(
            owner=self.stranger, name="Hidden", practice_language=self.language
        )

    def authenticate(self, user):
        login = self.client.post(
            reverse("accounts:login"),
            {"email": user.email, "password": "TeaCup!2026"},
            format="json",
        )
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {login.json()['access']}"
        )

    def test_a_student_cannot_use_the_supervisor_endpoints(self):
        self.authenticate(self.student_account)

        self.assertEqual(self.client.get("/api/students/").status_code, 403)

    def test_a_parent_sees_only_their_own_children(self):
        self.authenticate(self.parent)

        names = [item["name"] for item in self.client.get("/api/students/").json()]

        self.assertEqual(names, ["Ali"])

    def test_a_teacher_sees_nothing_until_linked(self):
        self.authenticate(self.teacher)

        self.assertEqual(self.client.get("/api/students/").json(), [])

    def test_a_linked_teacher_sees_that_learner(self):
        StudentLink.objects.create(
            supervisor=self.teacher, profile=self.own_child
        )
        self.authenticate(self.teacher)

        names = [item["name"] for item in self.client.get("/api/students/").json()]

        self.assertEqual(names, ["Ali"])

    def test_another_familys_child_is_not_reachable_by_id(self):
        self.authenticate(self.parent)

        response = self.client.get(
            f"/api/students/{self.other_child.id}/progress/"
        )

        self.assertEqual(response.status_code, 404)

    def test_a_supervisor_can_read_their_own_learners_progress(self):
        attempt(self.own_child, self.words[0], 82)
        self.authenticate(self.parent)

        response = self.client.get(
            f"/api/students/{self.own_child.id}/progress/"
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["profile"]["name"], "Ali")
        self.assertEqual(body["summary"]["practice_sessions"], 1)
        self.assertIn("weak_words", body)
