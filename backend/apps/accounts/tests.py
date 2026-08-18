"""Phase 2 tests: the user model, registration, login, JWT and role permissions."""

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APITestCase

from .models import LanguageCode, Role

User = get_user_model()


class UserModelTests(TestCase):
    def test_create_user_hashes_the_password(self):
        user = User.objects.create_user(
            email="amir@example.com", name="Amir", password="TeaCup!2026"
        )

        self.assertNotEqual(user.password, "TeaCup!2026")
        self.assertTrue(user.check_password("TeaCup!2026"))

    def test_email_is_normalised_to_lowercase(self):
        user = User.objects.create_user(
            email="  Amir@Example.COM ", name="Amir", password="TeaCup!2026"
        )

        self.assertEqual(user.email, "amir@example.com")

    def test_default_role_is_student(self):
        user = User.objects.create_user(
            email="amir@example.com", name="Amir", password="TeaCup!2026"
        )

        self.assertEqual(user.role, Role.STUDENT)
        self.assertTrue(user.is_student)
        self.assertFalse(user.supervises_students)

    def test_parents_and_teachers_supervise_students(self):
        parent = User.objects.create_user(
            email="p@example.com", name="P", password="TeaCup!2026", role=Role.PARENT
        )
        teacher = User.objects.create_user(
            email="t@example.com", name="T", password="TeaCup!2026", role=Role.TEACHER
        )

        self.assertTrue(parent.supervises_students)
        self.assertTrue(teacher.supervises_students)

    def test_email_must_be_unique(self):
        User.objects.create_user(
            email="amir@example.com", name="Amir", password="TeaCup!2026"
        )

        with self.assertRaises(Exception):
            User.objects.create_user(
                email="amir@example.com", name="Other", password="TeaCup!2026"
            )

    def test_create_user_requires_an_email(self):
        with self.assertRaises(ValueError):
            User.objects.create_user(email="", name="Amir", password="TeaCup!2026")

    def test_create_superuser_gets_staff_and_superuser_flags(self):
        admin = User.objects.create_superuser(
            email="admin@example.com", name="Admin", password="TeaCup!2026"
        )

        self.assertTrue(admin.is_staff)
        self.assertTrue(admin.is_superuser)


class RegistrationTests(APITestCase):
    url = reverse("accounts:register")

    def test_registration_creates_a_user_and_returns_tokens(self):
        response = self.client.post(
            self.url,
            {
                "name": "Amir",
                "email": "amir@example.com",
                "password": "TeaCup!2026",
                "password_confirm": "TeaCup!2026",
                "role": Role.STUDENT,
                "preferred_language": LanguageCode.MALAY,
            },
            format="json",
        )

        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertIn("access", body)
        self.assertIn("refresh", body)
        self.assertEqual(body["user"]["email"], "amir@example.com")
        self.assertEqual(body["user"]["preferred_language"], "ms")
        self.assertTrue(User.objects.filter(email="amir@example.com").exists())

    def test_response_never_contains_the_password(self):
        response = self.client.post(
            self.url,
            {
                "name": "Amir",
                "email": "amir@example.com",
                "password": "TeaCup!2026",
                "password_confirm": "TeaCup!2026",
            },
            format="json",
        )

        self.assertNotIn("password", response.json().get("user", {}))
        self.assertNotIn("TeaCup!2026", response.content.decode())

    def test_mismatched_passwords_are_rejected(self):
        response = self.client.post(
            self.url,
            {
                "name": "Amir",
                "email": "amir@example.com",
                "password": "TeaCup!2026",
                "password_confirm": "Different!2026",
            },
            format="json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("password_confirm", response.json())

    def test_weak_passwords_are_rejected(self):
        response = self.client.post(
            self.url,
            {
                "name": "Amir",
                "email": "amir@example.com",
                "password": "password",
                "password_confirm": "password",
            },
            format="json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("password", response.json())

    def test_duplicate_email_is_rejected_case_insensitively(self):
        User.objects.create_user(
            email="amir@example.com", name="Amir", password="TeaCup!2026"
        )

        response = self.client.post(
            self.url,
            {
                "name": "Amir Again",
                "email": "AMIR@example.com",
                "password": "TeaCup!2026",
                "password_confirm": "TeaCup!2026",
            },
            format="json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("email", response.json())

    def test_privilege_fields_cannot_be_set_at_registration(self):
        response = self.client.post(
            self.url,
            {
                "name": "Sneaky",
                "email": "sneaky@example.com",
                "password": "TeaCup!2026",
                "password_confirm": "TeaCup!2026",
                "is_staff": True,
                "is_superuser": True,
            },
            format="json",
        )

        self.assertEqual(response.status_code, 201)
        user = User.objects.get(email="sneaky@example.com")
        self.assertFalse(user.is_staff)
        self.assertFalse(user.is_superuser)


class LoginTests(APITestCase):
    url = reverse("accounts:login")

    def setUp(self):
        self.user = User.objects.create_user(
            email="amir@example.com", name="Amir", password="TeaCup!2026"
        )

    def test_valid_credentials_return_tokens_and_user(self):
        response = self.client.post(
            self.url,
            {"email": "amir@example.com", "password": "TeaCup!2026"},
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertIn("access", body)
        self.assertIn("refresh", body)
        self.assertEqual(body["user"]["name"], "Amir")

    def test_login_is_case_insensitive_on_email(self):
        response = self.client.post(
            self.url,
            {"email": "AMIR@Example.com", "password": "TeaCup!2026"},
            format="json",
        )

        self.assertEqual(response.status_code, 200)

    def test_wrong_password_is_rejected(self):
        response = self.client.post(
            self.url,
            {"email": "amir@example.com", "password": "WrongPassword!1"},
            format="json",
        )

        self.assertEqual(response.status_code, 401)

    def test_unknown_email_is_rejected(self):
        response = self.client.post(
            self.url,
            {"email": "nobody@example.com", "password": "TeaCup!2026"},
            format="json",
        )

        self.assertEqual(response.status_code, 401)

    def test_inactive_user_cannot_log_in(self):
        self.user.is_active = False
        self.user.save()

        response = self.client.post(
            self.url,
            {"email": "amir@example.com", "password": "TeaCup!2026"},
            format="json",
        )

        self.assertEqual(response.status_code, 401)


class TokenRefreshTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email="amir@example.com", name="Amir", password="TeaCup!2026"
        )
        login = self.client.post(
            reverse("accounts:login"),
            {"email": "amir@example.com", "password": "TeaCup!2026"},
            format="json",
        )
        self.refresh = login.json()["refresh"]

    def test_refresh_returns_a_new_access_token(self):
        response = self.client.post(
            reverse("accounts:refresh"), {"refresh": self.refresh}, format="json"
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn("access", response.json())

    def test_garbage_refresh_token_is_rejected(self):
        response = self.client.post(
            reverse("accounts:refresh"), {"refresh": "not-a-token"}, format="json"
        )

        self.assertEqual(response.status_code, 401)


class MeEndpointTests(APITestCase):
    url = reverse("accounts:me")

    def setUp(self):
        self.user = User.objects.create_user(
            email="amir@example.com", name="Amir", password="TeaCup!2026"
        )

    def authenticate(self, user=None):
        login = self.client.post(
            reverse("accounts:login"),
            {
                "email": (user or self.user).email,
                "password": "TeaCup!2026",
            },
            format="json",
        )
        token = login.json()["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_requires_authentication(self):
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 401)

    def test_a_malformed_token_is_rejected(self):
        self.client.credentials(HTTP_AUTHORIZATION="Bearer not-a-real-token")
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 401)

    def test_returns_the_signed_in_user(self):
        self.authenticate()
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["email"], "amir@example.com")

    def test_can_update_name_and_language(self):
        self.authenticate()
        response = self.client.patch(
            self.url, {"name": "Amir R.", "preferred_language": "ms"}, format="json"
        )

        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertEqual(self.user.name, "Amir R.")
        self.assertEqual(self.user.preferred_language, "ms")

    def test_role_and_email_cannot_be_changed_through_the_profile(self):
        self.authenticate()
        self.client.patch(
            self.url,
            {"role": Role.TEACHER, "email": "hacker@example.com"},
            format="json",
        )

        self.user.refresh_from_db()
        self.assertEqual(self.user.role, Role.STUDENT)
        self.assertEqual(self.user.email, "amir@example.com")


class RolePermissionTests(APITestCase):
    """Exercises the permission classes directly, since no role-gated
    endpoint exists yet - those arrive with the practice and dashboard APIs."""

    def setUp(self):
        from rest_framework.test import APIRequestFactory

        from .permissions import IsParentOrTeacher, IsStudent

        self.factory = APIRequestFactory()
        self.is_student = IsStudent()
        self.is_parent_or_teacher = IsParentOrTeacher()

    def _request_as(self, user):
        request = self.factory.get("/")
        request.user = user
        return request

    def test_student_passes_student_permission_only(self):
        student = User.objects.create_user(
            email="s@example.com", name="S", password="TeaCup!2026", role=Role.STUDENT
        )
        request = self._request_as(student)

        self.assertTrue(self.is_student.has_permission(request, None))
        self.assertFalse(self.is_parent_or_teacher.has_permission(request, None))

    def test_teacher_passes_supervisor_permission_only(self):
        teacher = User.objects.create_user(
            email="t@example.com", name="T", password="TeaCup!2026", role=Role.TEACHER
        )
        request = self._request_as(teacher)

        self.assertFalse(self.is_student.has_permission(request, None))
        self.assertTrue(self.is_parent_or_teacher.has_permission(request, None))

    def test_anonymous_user_passes_nothing(self):
        from django.contrib.auth.models import AnonymousUser

        request = self._request_as(AnonymousUser())

        self.assertFalse(self.is_student.has_permission(request, None))
        self.assertFalse(self.is_parent_or_teacher.has_permission(request, None))
