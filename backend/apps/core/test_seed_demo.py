"""Tests for the seed_demo management command."""

from django.contrib.auth import get_user_model
from django.core.management import CommandError, call_command
from django.test import TestCase, override_settings

from apps.practice.models import PracticeAttempt, QuizSession
from apps.profiles.models import Profile
from apps.progress.models import ProfileAchievement
from apps.progress.services import analytics

User = get_user_model()

EMAIL = "demo@hearspeak.test"


def seed_content():
    call_command("seed_data", verbosity=0)
    call_command("seed_achievements", verbosity=0)


class SeedDemoTests(TestCase):
    def test_refuses_to_run_in_production_without_force(self):
        """The account's password is in the source, so this must not run
        against a production database by accident."""
        seed_content()

        with override_settings(DEBUG=False):
            with self.assertRaises(CommandError) as caught:
                call_command("seed_demo", verbosity=0)

        self.assertIn("DEBUG=False", str(caught.exception))
        self.assertFalse(User.objects.filter(email=EMAIL).exists())

    @override_settings(DEBUG=False)
    def test_force_overrides_the_production_guard(self):
        seed_content()

        call_command("seed_demo", "--force", verbosity=0)

        self.assertTrue(User.objects.filter(email=EMAIL).exists())

    @override_settings(DEBUG=True)
    def test_fails_clearly_when_content_is_missing(self):
        with self.assertRaises(CommandError) as caught:
            call_command("seed_demo", verbosity=0)

        self.assertIn("seed_data", str(caught.exception))

    @override_settings(DEBUG=True)
    def test_creates_an_account_with_two_learners(self):
        seed_content()

        call_command("seed_demo", verbosity=0)

        user = User.objects.get(email=EMAIL)
        # A parent, so the supervisor view is reachable in the demo.
        self.assertEqual(user.role, "PARENT")
        self.assertEqual(user.profiles.count(), 2)

    @override_settings(DEBUG=True)
    def test_builds_practice_history_and_awards_badges(self):
        seed_content()

        call_command("seed_demo", verbosity=0)
        profile = Profile.objects.get(name="Ali")

        self.assertGreater(
            PracticeAttempt.objects.filter(profile=profile).count(), 0
        )
        self.assertGreater(QuizSession.objects.filter(profile=profile).count(), 0)
        self.assertGreater(profile.points, 0)
        self.assertGreater(
            ProfileAchievement.objects.filter(profile=profile).count(), 0
        )

    @override_settings(DEBUG=True)
    def test_produces_weak_words_for_the_analytics_to_flag(self):
        """The demo is useless if the progress screen has nothing to show."""
        seed_content()

        call_command("seed_demo", verbosity=0)
        profile = Profile.objects.get(name="Ali")

        self.assertGreater(len(analytics.weak_words(profile)), 0)

    @override_settings(DEBUG=True)
    def test_malay_demo_data_never_invents_a_prosody_score(self):
        """Azure does not assess prosody for ms-MY, so seeded data must not
        imply a measurement the real system cannot make."""
        seed_content()

        call_command("seed_demo", verbosity=0)
        malay_attempts = PracticeAttempt.objects.filter(language_code="ms")

        self.assertGreater(malay_attempts.count(), 0)
        self.assertFalse(malay_attempts.exclude(prosody_score=None).exists())

    @override_settings(DEBUG=True)
    def test_english_demo_data_does_carry_prosody(self):
        seed_content()

        call_command("seed_demo", verbosity=0)
        english_attempts = PracticeAttempt.objects.filter(language_code="en")

        self.assertTrue(english_attempts.exclude(prosody_score=None).exists())

    @override_settings(DEBUG=True)
    def test_rerunning_resets_rather_than_accumulates(self):
        seed_content()

        call_command("seed_demo", verbosity=0)
        first_attempts = PracticeAttempt.objects.count()
        first_points = Profile.objects.get(name="Ali").points

        call_command("seed_demo", verbosity=0)

        self.assertEqual(PracticeAttempt.objects.count(), first_attempts)
        self.assertEqual(Profile.objects.get(name="Ali").points, first_points)
        self.assertEqual(User.objects.filter(email=EMAIL).count(), 1)
        self.assertEqual(Profile.objects.filter(name="Ali").count(), 1)

    @override_settings(DEBUG=True)
    def test_a_custom_email_can_be_supplied(self):
        seed_content()

        call_command("seed_demo", "--email", "other@example.com", verbosity=0)

        self.assertTrue(User.objects.filter(email="other@example.com").exists())
