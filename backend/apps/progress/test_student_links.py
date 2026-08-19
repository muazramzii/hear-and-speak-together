"""Phase 7 tests: linking a teacher to a learner by share code.

This is the most security-sensitive flow in the project - a share code grants
a stranger read access to a child's progress - so the negative cases matter
more than the happy path.
"""

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APITestCase

from apps.accounts.models import Role
from apps.content.models import Language
from apps.profiles.models import Profile, generate_share_code

from .models import StudentLink

User = get_user_model()


class ShareCodeTests(TestCase):
    def setUp(self):
        self.language = Language.objects.create(
            code="en", name="English", locale="en-US"
        )
        self.user = User.objects.create_user(
            email="p@example.com", name="P", password="TeaCup!2026"
        )

    def test_a_profile_gets_a_code_automatically(self):
        profile = Profile.objects.create(
            owner=self.user, name="Ali", practice_language=self.language
        )

        self.assertEqual(len(profile.share_code), 8)

    def test_codes_are_unique_across_profiles(self):
        codes = {
            Profile.objects.create(
                owner=self.user, name=f"Child{i}", practice_language=self.language
            ).share_code
            for i in range(20)
        }

        self.assertEqual(len(codes), 20)

    def test_codes_avoid_easily_misread_characters(self):
        """The code gets read aloud or copied by hand, so 0/O and 1/I/L are
        excluded from the alphabet."""
        codes = "".join(generate_share_code() for _ in range(200))

        for character in "01OIL":
            self.assertNotIn(character, codes)

    def test_regenerating_produces_a_different_code(self):
        profile = Profile.objects.create(
            owner=self.user, name="Ali", practice_language=self.language
        )
        original = profile.share_code

        profile.regenerate_share_code()

        self.assertNotEqual(profile.share_code, original)


class LinkStudentAPITests(APITestCase):
    def setUp(self):
        self.language = Language.objects.create(
            code="en", name="English", locale="en-US"
        )
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
        self.child = Profile.objects.create(
            owner=self.parent, name="Ali", practice_language=self.language
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

    def link(self, code):
        return self.client.post(
            "/api/students/link/", {"share_code": code}, format="json"
        )

    def test_requires_authentication(self):
        self.assertEqual(self.link(self.child.share_code).status_code, 401)

    def test_a_student_account_cannot_link_to_anyone(self):
        self.authenticate(self.student_account)

        self.assertEqual(self.link(self.child.share_code).status_code, 403)

    def test_a_teacher_links_with_a_valid_code(self):
        self.authenticate(self.teacher)

        response = self.link(self.child.share_code)

        self.assertEqual(response.status_code, 201)
        self.assertTrue(
            StudentLink.objects.filter(
                supervisor=self.teacher, profile=self.child
            ).exists()
        )

    def test_the_code_is_accepted_case_insensitively(self):
        self.authenticate(self.teacher)

        response = self.link(self.child.share_code.lower())

        self.assertEqual(response.status_code, 201)

    def test_an_invalid_code_is_rejected(self):
        self.authenticate(self.teacher)

        response = self.link("ZZZZZZZZ")

        self.assertEqual(response.status_code, 400)
        self.assertFalse(StudentLink.objects.exists())

    def test_an_empty_code_is_rejected(self):
        self.authenticate(self.teacher)

        self.assertEqual(self.link("").status_code, 400)

    def test_linking_twice_does_not_duplicate(self):
        self.authenticate(self.teacher)
        self.link(self.child.share_code)

        response = self.link(self.child.share_code)

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["already_linked"])
        self.assertEqual(StudentLink.objects.count(), 1)

    def test_an_owner_cannot_link_to_their_own_child(self):
        self.authenticate(self.parent)

        response = self.link(self.child.share_code)

        self.assertEqual(response.status_code, 400)
        self.assertFalse(StudentLink.objects.exists())

    def test_a_regenerated_code_stops_working(self):
        old_code = self.child.share_code
        self.child.regenerate_share_code()
        self.child.save()

        self.authenticate(self.teacher)

        self.assertEqual(self.link(old_code).status_code, 400)
        self.assertEqual(self.link(self.child.share_code).status_code, 201)

    def test_linking_grants_access_to_that_learners_progress(self):
        self.authenticate(self.teacher)
        self.link(self.child.share_code)

        response = self.client.get(f"/api/students/{self.child.id}/progress/")

        self.assertEqual(response.status_code, 200)

    def test_unlinking_removes_access_again(self):
        self.authenticate(self.teacher)
        self.link(self.child.share_code)

        response = self.client.delete(f"/api/students/{self.child.id}/link/")

        self.assertEqual(response.status_code, 204)
        self.assertEqual(
            self.client.get(
                f"/api/students/{self.child.id}/progress/"
            ).status_code,
            404,
        )

    def test_unlinking_something_not_linked_is_a_404(self):
        self.authenticate(self.teacher)

        response = self.client.delete(f"/api/students/{self.child.id}/link/")

        self.assertEqual(response.status_code, 404)

    def test_a_teacher_cannot_unlink_another_supervisors_link(self):
        other_teacher = User.objects.create_user(
            email="other@example.com",
            name="Other",
            password="TeaCup!2026",
            role=Role.TEACHER,
        )
        StudentLink.objects.create(
            supervisor=other_teacher, profile=self.child
        )

        self.authenticate(self.teacher)
        response = self.client.delete(f"/api/students/{self.child.id}/link/")

        self.assertEqual(response.status_code, 404)
        self.assertTrue(
            StudentLink.objects.filter(supervisor=other_teacher).exists()
        )
