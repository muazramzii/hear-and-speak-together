"""Phase 3 tests: learner profiles, ownership isolation and gamification."""

from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APITestCase

from apps.content.models import Language

from .models import Avatar, Profile

User = get_user_model()


def make_language(code="en", locale="en-US"):
    return Language.objects.create(code=code, name=code.upper(), locale=locale)


class ProfileModelTests(TestCase):
    def setUp(self):
        self.language = make_language()
        self.user = User.objects.create_user(
            email="parent@example.com", name="Parent", password="TeaCup!2026"
        )
        self.profile = Profile.objects.create(
            owner=self.user, name="Ali", practice_language=self.language
        )

    def test_a_new_profile_starts_at_level_one(self):
        self.assertEqual(self.profile.level_from_points, 1)
        self.assertEqual(self.profile.points, 0)
        self.assertEqual(self.profile.points_to_next_level, 100)

    def test_level_is_derived_from_points(self):
        self.profile.award_points(230)

        self.assertEqual(self.profile.points, 230)
        self.assertEqual(self.profile.level, 3)
        self.assertEqual(self.profile.points_into_level, 30)
        self.assertEqual(self.profile.points_to_next_level, 70)

    def test_negative_awards_are_ignored(self):
        self.profile.award_points(-50)

        self.assertEqual(self.profile.points, 0)

    def test_one_account_can_hold_several_children(self):
        Profile.objects.create(
            owner=self.user, name="Sofia", practice_language=self.language
        )
        Profile.objects.create(
            owner=self.user, name="Aiman", practice_language=self.language
        )

        self.assertEqual(self.user.profiles.count(), 3)

    def test_profile_names_are_unique_per_owner(self):
        with self.assertRaises(Exception):
            Profile.objects.create(
                owner=self.user, name="Ali", practice_language=self.language
            )

    def test_different_owners_may_reuse_a_name(self):
        other = User.objects.create_user(
            email="other@example.com", name="Other", password="TeaCup!2026"
        )
        Profile.objects.create(
            owner=other, name="Ali", practice_language=self.language
        )

        self.assertEqual(Profile.objects.filter(name="Ali").count(), 2)


class StreakTests(TestCase):
    def setUp(self):
        self.language = make_language()
        self.user = User.objects.create_user(
            email="p@example.com", name="P", password="TeaCup!2026"
        )
        self.profile = Profile.objects.create(
            owner=self.user, name="Ali", practice_language=self.language
        )
        self.today = date(2026, 8, 19)

    def test_first_practice_starts_a_streak_of_one(self):
        self.profile.register_practice(on_date=self.today)

        self.assertEqual(self.profile.streak_days, 1)
        self.assertEqual(self.profile.last_practised_on, self.today)

    def test_practising_again_the_same_day_does_not_double_count(self):
        self.profile.register_practice(on_date=self.today)
        self.profile.register_practice(on_date=self.today)

        self.assertEqual(self.profile.streak_days, 1)

    def test_consecutive_days_extend_the_streak(self):
        self.profile.register_practice(on_date=self.today)
        self.profile.register_practice(on_date=self.today + timedelta(days=1))
        self.profile.register_practice(on_date=self.today + timedelta(days=2))

        self.assertEqual(self.profile.streak_days, 3)

    def test_a_missed_day_resets_the_streak(self):
        self.profile.register_practice(on_date=self.today)
        self.profile.register_practice(on_date=self.today + timedelta(days=1))
        self.profile.register_practice(on_date=self.today + timedelta(days=5))

        self.assertEqual(self.profile.streak_days, 1)


class ProfileAPITests(APITestCase):
    def setUp(self):
        self.language = make_language()
        make_language(code="ms", locale="ms-MY")

        self.user = User.objects.create_user(
            email="parent@example.com", name="Parent", password="TeaCup!2026"
        )
        self.other = User.objects.create_user(
            email="other@example.com", name="Other", password="TeaCup!2026"
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

    def test_requires_authentication(self):
        self.client.credentials()

        self.assertEqual(self.client.get("/api/profiles/").status_code, 401)

    def test_create_a_profile(self):
        response = self.client.post(
            "/api/profiles/",
            {
                "name": "Ali",
                "avatar": Avatar.BOY_1,
                "practice_language": "ms",
            },
            format="json",
        )

        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertEqual(body["name"], "Ali")
        self.assertEqual(body["language_code"], "ms")
        self.assertEqual(body["level"], 1)

    def test_owner_cannot_be_spoofed_from_the_request(self):
        self.client.post(
            "/api/profiles/",
            {
                "name": "Ali",
                "practice_language": "en",
                "owner": self.other.id,
            },
            format="json",
        )

        self.assertTrue(Profile.objects.filter(name="Ali", owner=self.user).exists())
        self.assertFalse(Profile.objects.filter(owner=self.other).exists())

    def test_only_own_profiles_are_listed(self):
        Profile.objects.create(
            owner=self.user, name="Ali", practice_language=self.language
        )
        Profile.objects.create(
            owner=self.other, name="Hidden", practice_language=self.language
        )

        names = [item["name"] for item in self.client.get("/api/profiles/").json()]

        self.assertEqual(names, ["Ali"])

    def test_another_users_profile_is_not_reachable(self):
        theirs = Profile.objects.create(
            owner=self.other, name="Hidden", practice_language=self.language
        )

        response = self.client.get(f"/api/profiles/{theirs.id}/")

        self.assertEqual(response.status_code, 404)

    def test_another_users_profile_cannot_be_edited(self):
        theirs = Profile.objects.create(
            owner=self.other, name="Hidden", practice_language=self.language
        )

        response = self.client.patch(
            f"/api/profiles/{theirs.id}/", {"name": "Hijacked"}, format="json"
        )

        self.assertEqual(response.status_code, 404)
        theirs.refresh_from_db()
        self.assertEqual(theirs.name, "Hidden")

    def test_duplicate_name_for_the_same_owner_is_rejected(self):
        Profile.objects.create(
            owner=self.user, name="Ali", practice_language=self.language
        )

        response = self.client.post(
            "/api/profiles/",
            {"name": "ali", "practice_language": "en"},
            format="json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("name", response.json())

    def test_switching_practice_language(self):
        profile = Profile.objects.create(
            owner=self.user, name="Ali", practice_language=self.language
        )

        response = self.client.patch(
            f"/api/profiles/{profile.id}/",
            {"practice_language": "ms"},
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["language_code"], "ms")

    def test_points_and_level_are_read_only_over_the_api(self):
        profile = Profile.objects.create(
            owner=self.user, name="Ali", practice_language=self.language
        )

        self.client.patch(
            f"/api/profiles/{profile.id}/",
            {"points": 9999, "level": 50},
            format="json",
        )

        profile.refresh_from_db()
        self.assertEqual(profile.points, 0)
        self.assertEqual(profile.level, 1)

    def test_deleting_a_profile(self):
        profile = Profile.objects.create(
            owner=self.user, name="Ali", practice_language=self.language
        )

        response = self.client.delete(f"/api/profiles/{profile.id}/")

        self.assertEqual(response.status_code, 204)
        self.assertFalse(Profile.objects.filter(pk=profile.pk).exists())
