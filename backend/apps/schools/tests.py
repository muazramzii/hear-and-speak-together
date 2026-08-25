"""Phase 6 Task 3 and Task 4: the tenant-isolation permission layer, and the
School management API built on top of it.

`SchoolTenancyTestCase`'s permission tests exercise `apps.schools.permissions`
directly against real database rows - no mocks - covering same-school access,
cross-school denial, every `ClassroomMembership` role, and (to prove the new
layer does not regress anything) the existing, frozen Parent/Student
`accessible_profiles` rule. `SchoolAPITests` (Task 4) drives the same
guarantees through the real HTTP API, authenticating with a genuine JWT
login rather than a mock, matching this project's existing API test style.

`APIRequestFactory` builds a real Django/DRF request object so
`has_permission`/`has_object_permission` are called exactly as a view would
call them; `view` is passed as `None` throughout because none of these
permission classes read anything from it.
"""

from datetime import timedelta

from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APIRequestFactory, APITestCase

from apps.accounts.models import Role
from apps.content.models import Category, Language, Lesson, Word
from apps.practice.models import PracticeAttempt
from apps.profiles.access import accessible_profiles
from apps.profiles.models import Profile

from .models import (
    Classroom,
    ClassroomMembership,
    ClassroomStaffRole,
    School,
    TeacherInvitation,
)
from .permissions import IsClassroomTeacher, IsSchoolAdmin, IsTeacherOfSchool, SchoolScopedQuerySet

User = get_user_model()
factory = APIRequestFactory()


def make_word(language_code="en"):
    language = Language.objects.create(
        code=language_code, name=language_code.upper(), locale=f"{language_code}-US"
    )
    category = Category.objects.create(
        language=language, slug="animals", name="Animals"
    )
    lesson = Lesson.objects.create(category=category, title="Animals")
    return language, Word.objects.create(lesson=lesson, text="elephant")


def request_as(user):
    request = factory.get("/")
    request.user = user
    return request


class SchoolTenancyTestCase(TestCase):
    """Shared fixture: two schools, each with one classroom, so every test
    can assert both "allowed within your own tenant" and "denied across
    tenants" without rebuilding the world each time."""

    def setUp(self):
        self.language, self.word = make_word()

        self.admin_a = User.objects.create_user(
            email="admin-a@example.com",
            name="Admin A",
            password="TeaCup!2026",
            role=Role.SCHOOL_ADMIN,
        )
        self.admin_b = User.objects.create_user(
            email="admin-b@example.com",
            name="Admin B",
            password="TeaCup!2026",
            role=Role.SCHOOL_ADMIN,
        )
        self.school_a = School.objects.create(name="School A", admin=self.admin_a)
        self.school_b = School.objects.create(name="School B", admin=self.admin_b)
        self.admin_a.school = self.school_a
        self.admin_a.save()
        self.admin_b.school = self.school_b
        self.admin_b.save()

        self.classroom_a1 = Classroom.objects.create(
            school=self.school_a, name="Classroom A1"
        )
        self.classroom_b1 = Classroom.objects.create(
            school=self.school_b, name="Classroom B1"
        )

        self.teacher_a = User.objects.create_user(
            email="teacher-a@example.com",
            name="Teacher A",
            password="TeaCup!2026",
            role=Role.TEACHER,
            school=self.school_a,
        )
        self.teacher_b = User.objects.create_user(
            email="teacher-b@example.com",
            name="Teacher B",
            password="TeaCup!2026",
            role=Role.TEACHER,
            school=self.school_b,
        )
        self.assistant_a = User.objects.create_user(
            email="assistant-a@example.com",
            name="Assistant A",
            password="TeaCup!2026",
            role=Role.TEACHER,
            school=self.school_a,
        )
        self.therapist_a = User.objects.create_user(
            email="therapist-a@example.com",
            name="Therapist A",
            password="TeaCup!2026",
            role=Role.TEACHER,
            school=self.school_a,
        )
        self.non_member_teacher = User.objects.create_user(
            email="floating-teacher@example.com",
            name="Floating Teacher",
            password="TeaCup!2026",
            role=Role.TEACHER,
            school=self.school_a,
        )

        ClassroomMembership.objects.create(
            classroom=self.classroom_a1,
            teacher=self.teacher_a,
            role=ClassroomStaffRole.LEAD_TEACHER,
        )
        ClassroomMembership.objects.create(
            classroom=self.classroom_a1,
            teacher=self.assistant_a,
            role=ClassroomStaffRole.ASSISTANT,
        )
        ClassroomMembership.objects.create(
            classroom=self.classroom_a1,
            teacher=self.therapist_a,
            role=ClassroomStaffRole.THERAPIST,
        )
        ClassroomMembership.objects.create(
            classroom=self.classroom_b1,
            teacher=self.teacher_b,
            role=ClassroomStaffRole.LEAD_TEACHER,
        )


class IsSchoolAdminTests(SchoolTenancyTestCase):
    def test_role_gate_rejects_non_admin(self):
        self.assertFalse(
            IsSchoolAdmin().has_permission(request_as(self.teacher_a), None)
        )

    def test_role_gate_allows_admin(self):
        self.assertTrue(
            IsSchoolAdmin().has_permission(request_as(self.admin_a), None)
        )

    def test_admin_allowed_on_own_school(self):
        self.assertTrue(
            IsSchoolAdmin().has_object_permission(
                request_as(self.admin_a), None, self.school_a
            )
        )

    def test_admin_denied_on_a_different_school(self):
        self.assertFalse(
            IsSchoolAdmin().has_object_permission(
                request_as(self.admin_b), None, self.school_a
            )
        )


class IsTeacherOfSchoolTests(SchoolTenancyTestCase):
    def test_teacher_allowed_on_own_school(self):
        self.assertTrue(
            IsTeacherOfSchool().has_object_permission(
                request_as(self.teacher_a), None, self.school_a
            )
        )

    def test_teacher_denied_on_a_different_school(self):
        self.assertFalse(
            IsTeacherOfSchool().has_object_permission(
                request_as(self.teacher_b), None, self.school_a
            )
        )

    def test_teacher_denied_on_a_classroom_in_a_different_school(self):
        """Same rule, expressed against a Classroom rather than a School -
        proves the school is resolved transitively."""
        self.assertFalse(
            IsTeacherOfSchool().has_object_permission(
                request_as(self.teacher_b), None, self.classroom_a1
            )
        )


class IsClassroomTeacherTests(SchoolTenancyTestCase):
    def test_lead_teacher_is_allowed(self):
        self.assertTrue(
            IsClassroomTeacher().has_object_permission(
                request_as(self.teacher_a), None, self.classroom_a1
            )
        )

    def test_assistant_is_allowed(self):
        self.assertTrue(
            IsClassroomTeacher().has_object_permission(
                request_as(self.assistant_a), None, self.classroom_a1
            )
        )

    def test_therapist_is_allowed(self):
        self.assertTrue(
            IsClassroomTeacher().has_object_permission(
                request_as(self.therapist_a), None, self.classroom_a1
            )
        )

    def test_non_member_is_denied(self):
        self.assertFalse(
            IsClassroomTeacher().has_object_permission(
                request_as(self.non_member_teacher), None, self.classroom_a1
            )
        )

    def test_teacher_from_another_school_is_denied(self):
        self.assertFalse(
            IsClassroomTeacher().has_object_permission(
                request_as(self.teacher_b), None, self.classroom_a1
            )
        )

    def test_membership_is_checked_against_the_database_not_school_id(self):
        """A teacher whose `User.school` matches, but who has never been
        given a `ClassroomMembership` row, must still be denied - school
        membership alone is not classroom membership."""
        self.assertFalse(
            IsClassroomTeacher().has_object_permission(
                request_as(self.non_member_teacher), None, self.classroom_a1
            )
        )
        self.assertEqual(self.non_member_teacher.school_id, self.school_a.id)


class ParentAndStudentAccessTests(SchoolTenancyTestCase):
    """The Phase 6 brief requires these rows of the Authorization Rules
    table to be tested too, even though this task does not change them -
    proving the new School/Classroom layer sits alongside the existing
    `accessible_profiles` rule rather than interfering with it."""

    def setUp(self):
        super().setUp()
        self.parent = User.objects.create_user(
            email="parent@example.com",
            name="Parent",
            password="TeaCup!2026",
            role=Role.PARENT,
        )
        self.other_parent = User.objects.create_user(
            email="other-parent@example.com",
            name="Other Parent",
            password="TeaCup!2026",
            role=Role.PARENT,
        )
        self.child = Profile.objects.create(
            owner=self.parent, name="Ali", practice_language=self.language
        )
        self.other_child = Profile.objects.create(
            owner=self.other_parent, name="Siti", practice_language=self.language
        )

        self.student_user = User.objects.create_user(
            email="student@example.com",
            name="Student",
            password="TeaCup!2026",
            role=Role.STUDENT,
        )
        self.own_profile = Profile.objects.create(
            owner=self.student_user, name="Amir", practice_language=self.language
        )

    def test_parent_can_access_their_own_linked_child(self):
        self.assertIn(self.child, accessible_profiles(self.parent))

    def test_parent_cannot_access_another_parents_child(self):
        self.assertNotIn(self.other_child, accessible_profiles(self.parent))

    def test_student_can_access_their_own_profile(self):
        self.assertIn(self.own_profile, accessible_profiles(self.student_user))

    def test_student_cannot_access_another_profile(self):
        self.assertNotIn(self.child, accessible_profiles(self.student_user))


class SchoolScopedQuerySetTests(SchoolTenancyTestCase):
    def setUp(self):
        super().setUp()
        self.profile_a = Profile.objects.create(
            owner=self.admin_a,
            name="Learner A",
            practice_language=self.language,
            classroom=self.classroom_a1,
        )
        self.profile_b = Profile.objects.create(
            owner=self.admin_b,
            name="Learner B",
            practice_language=self.language,
            classroom=self.classroom_b1,
        )
        self.attempt_a = PracticeAttempt.objects.create(
            profile=self.profile_a,
            word=self.word,
            language_code="en",
            locale="en-US",
            reference_text="elephant",
            pronunciation_score=80,
        )
        self.attempt_b = PracticeAttempt.objects.create(
            profile=self.profile_b,
            word=self.word,
            language_code="en",
            locale="en-US",
            reference_text="elephant",
            pronunciation_score=60,
        )

    def test_users_for_school_excludes_other_schools_staff(self):
        result = SchoolScopedQuerySet.users_for_school(self.school_a)
        self.assertIn(self.teacher_a, result)
        self.assertNotIn(self.teacher_b, result)

    def test_classrooms_for_school_excludes_other_schools_classrooms(self):
        result = SchoolScopedQuerySet.classrooms_for_school(self.school_a)
        self.assertIn(self.classroom_a1, result)
        self.assertNotIn(self.classroom_b1, result)

    def test_profiles_for_school_scopes_by_classroom(self):
        result = SchoolScopedQuerySet.profiles_for_school(self.school_a)
        self.assertIn(self.profile_a, result)
        self.assertNotIn(self.profile_b, result)

    def test_attempts_for_school_scopes_transitively_through_classroom(self):
        result = SchoolScopedQuerySet.attempts_for_school(self.school_a)
        self.assertIn(self.attempt_a, result)
        self.assertNotIn(self.attempt_b, result)

    def test_classrooms_for_teacher_only_returns_their_memberships(self):
        result = SchoolScopedQuerySet.classrooms_for_teacher(self.teacher_a)
        self.assertIn(self.classroom_a1, result)
        self.assertNotIn(self.classroom_b1, result)

    def test_profiles_for_teacher_only_returns_their_classrooms_students(self):
        result = SchoolScopedQuerySet.profiles_for_teacher(self.teacher_a)
        self.assertIn(self.profile_a, result)
        self.assertNotIn(self.profile_b, result)

    def test_attempts_for_teacher_only_returns_their_classrooms_attempts(self):
        result = SchoolScopedQuerySet.attempts_for_teacher(self.teacher_a)
        self.assertIn(self.attempt_a, result)
        self.assertNotIn(self.attempt_b, result)


class SchoolAPITests(APITestCase):
    """Phase 6 Task 4: `/api/schools/`, driven exactly as a client would -
    real JWT login, real HTTP verbs, no mocks. Cross-tenant requests are
    expected to come back 404, not 403: the queryset itself excludes any
    school the caller doesn't belong to, so a wrong id is indistinguishable
    from a non-existent one rather than leaking "yes, that school exists."
    """

    def setUp(self):
        self.admin_a = User.objects.create_user(
            email="api-admin-a@example.com",
            name="Admin A",
            password="TeaCup!2026",
            role=Role.SCHOOL_ADMIN,
        )
        self.admin_b = User.objects.create_user(
            email="api-admin-b@example.com",
            name="Admin B",
            password="TeaCup!2026",
            role=Role.SCHOOL_ADMIN,
        )
        self.school_a = School.objects.create(name="School A", admin=self.admin_a)
        self.admin_a.school = self.school_a
        self.admin_a.save()

        self.school_b = School.objects.create(name="School B", admin=self.admin_b)
        self.admin_b.school = self.school_b
        self.admin_b.save()

        self.teacher_a = User.objects.create_user(
            email="api-teacher-a@example.com",
            name="Teacher A",
            password="TeaCup!2026",
            role=Role.TEACHER,
            school=self.school_a,
        )
        self.parent = User.objects.create_user(
            email="api-parent@example.com",
            name="Parent",
            password="TeaCup!2026",
            role=Role.PARENT,
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

    def test_requires_authentication(self):
        response = self.client.get("/api/schools/")
        self.assertEqual(response.status_code, 401)

    def test_school_admin_can_create_school(self):
        self.authenticate(self.admin_a)

        response = self.client.post(
            "/api/schools/", {"name": "New Horizons"}, format="json"
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["name"], "New Horizons")
        self.assertEqual(response.json()["admin_email"], self.admin_a.email)

    def test_creating_a_school_assigns_the_creator_as_its_staff(self):
        """Without this, the creator's own `GET /api/schools/` would come
        back empty until a separate step assigned them to it."""
        fresh_admin = User.objects.create_user(
            email="fresh-admin@example.com",
            name="Fresh Admin",
            password="TeaCup!2026",
            role=Role.SCHOOL_ADMIN,
        )
        self.authenticate(fresh_admin)

        response = self.client.post(
            "/api/schools/", {"name": "Brand New School"}, format="json"
        )

        fresh_admin.refresh_from_db()
        self.assertEqual(fresh_admin.school_id, response.json()["id"])

    def test_teacher_cannot_create_school(self):
        self.authenticate(self.teacher_a)

        response = self.client.post(
            "/api/schools/", {"name": "Teacher's School"}, format="json"
        )

        self.assertEqual(response.status_code, 403)

    def test_parent_cannot_create_school(self):
        self.authenticate(self.parent)

        response = self.client.post(
            "/api/schools/", {"name": "Parent's School"}, format="json"
        )

        self.assertEqual(response.status_code, 403)

    def test_list_returns_only_the_authenticated_users_school(self):
        self.authenticate(self.admin_a)

        response = self.client.get("/api/schools/")

        ids = [item["id"] for item in response.json()]
        self.assertEqual(ids, [self.school_a.id])

    def test_admin_can_view_own_school_detail(self):
        self.authenticate(self.admin_a)

        response = self.client.get(f"/api/schools/{self.school_a.id}/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["name"], "School A")

    def test_teacher_can_view_their_own_school_detail(self):
        self.authenticate(self.teacher_a)

        response = self.client.get(f"/api/schools/{self.school_a.id}/")

        self.assertEqual(response.status_code, 200)

    def test_cross_school_admin_detail_is_not_found(self):
        self.authenticate(self.admin_b)

        response = self.client.get(f"/api/schools/{self.school_a.id}/")

        self.assertEqual(response.status_code, 404)

    def test_admin_can_patch_own_school(self):
        self.authenticate(self.admin_a)

        response = self.client.patch(
            f"/api/schools/{self.school_a.id}/",
            {"name": "School A Renamed"},
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        self.school_a.refresh_from_db()
        self.assertEqual(self.school_a.name, "School A Renamed")

    def test_teacher_cannot_patch_their_own_school(self):
        """Read access is not write access - a same-school TEACHER passes
        the queryset scope but is rejected by the SCHOOL_ADMIN role gate."""
        self.authenticate(self.teacher_a)

        response = self.client.patch(
            f"/api/schools/{self.school_a.id}/",
            {"name": "Hijacked"},
            format="json",
        )

        self.assertEqual(response.status_code, 403)

    def test_admin_cannot_patch_a_different_schools_school(self):
        self.authenticate(self.admin_b)

        response = self.client.patch(
            f"/api/schools/{self.school_a.id}/",
            {"name": "Hijacked"},
            format="json",
        )

        self.assertEqual(response.status_code, 404)
        self.school_a.refresh_from_db()
        self.assertEqual(self.school_a.name, "School A")

    def test_soft_delete_deactivates_without_removing_the_row(self):
        self.authenticate(self.admin_a)

        response = self.client.delete(f"/api/schools/{self.school_a.id}/")

        self.assertEqual(response.status_code, 204)
        self.assertTrue(School.objects.filter(id=self.school_a.id).exists())
        self.school_a.refresh_from_db()
        self.assertFalse(self.school_a.is_active)


class TeacherInvitationAPITests(APITestCase):
    """Phase 6 Task 5: `/api/schools/invitations/`, driven exactly as a
    client would - real JWT login, real HTTP verbs, no mocks."""

    def setUp(self):
        self.admin_a = User.objects.create_user(
            email="inv-admin-a@example.com",
            name="Admin A",
            password="TeaCup!2026",
            role=Role.SCHOOL_ADMIN,
        )
        self.admin_b = User.objects.create_user(
            email="inv-admin-b@example.com",
            name="Admin B",
            password="TeaCup!2026",
            role=Role.SCHOOL_ADMIN,
        )
        self.school_a = School.objects.create(name="School A", admin=self.admin_a)
        self.admin_a.school = self.school_a
        self.admin_a.save()

        self.school_b = School.objects.create(name="School B", admin=self.admin_b)
        self.admin_b.school = self.school_b
        self.admin_b.save()

        self.teacher_a = User.objects.create_user(
            email="inv-teacher-a@example.com",
            name="Teacher A",
            password="TeaCup!2026",
            role=Role.TEACHER,
            school=self.school_a,
        )
        self.parent = User.objects.create_user(
            email="inv-parent@example.com",
            name="Parent",
            password="TeaCup!2026",
            role=Role.PARENT,
        )
        # No school yet - the realistic case for someone about to become
        # a teacher via an invitation.
        self.prospective_teacher = User.objects.create_user(
            email="prospective@example.com",
            name="Prospective Teacher",
            password="TeaCup!2026",
            role=Role.STUDENT,
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

    def make_invitation(self, **overrides):
        defaults = {
            "school": self.school_a,
            "invited_by": self.admin_a,
            "email": "invitee@example.com",
        }
        defaults.update(overrides)
        return TeacherInvitation.objects.create(**defaults)

    # -- create ------------------------------------------------------

    def test_admin_can_create_invitation(self):
        self.authenticate(self.admin_a)

        response = self.client.post(
            "/api/schools/invitations/",
            {"email": "new.teacher@example.com"},
            format="json",
        )

        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertEqual(len(body["invitation_code"]), 8)
        self.assertEqual(body["school_name"], "School A")
        self.assertIn("expires_at", body)

    def test_invitation_code_is_unique_uppercase_alphanumeric(self):
        first = self.make_invitation(email="a@example.com")
        second = self.make_invitation(email="b@example.com")

        self.assertNotEqual(first.invitation_code, second.invitation_code)
        self.assertEqual(len(first.invitation_code), 8)
        self.assertTrue(first.invitation_code.isalnum())
        self.assertEqual(first.invitation_code, first.invitation_code.upper())

    def test_invitation_expires_seven_days_from_creation(self):
        invitation = self.make_invitation()

        delta = invitation.expires_at - invitation.created_at
        self.assertAlmostEqual(delta.total_seconds(), timedelta(days=7).total_seconds(), delta=5)

    def test_teacher_cannot_create_invitation(self):
        self.authenticate(self.teacher_a)

        response = self.client.post(
            "/api/schools/invitations/",
            {"email": "x@example.com"},
            format="json",
        )

        self.assertEqual(response.status_code, 403)

    def test_parent_cannot_create_invitation(self):
        self.authenticate(self.parent)

        response = self.client.post(
            "/api/schools/invitations/",
            {"email": "x@example.com"},
            format="json",
        )

        self.assertEqual(response.status_code, 403)

    def test_unauthenticated_cannot_create_invitation(self):
        response = self.client.post(
            "/api/schools/invitations/",
            {"email": "x@example.com"},
            format="json",
        )

        self.assertEqual(response.status_code, 401)

    # -- list ----------------------------------------------------------

    def test_list_returns_only_same_school_invitations(self):
        self.make_invitation(email="a@example.com")
        self.make_invitation(school=self.school_b, invited_by=self.admin_b, email="b@example.com")

        self.authenticate(self.admin_a)
        response = self.client.get("/api/schools/invitations/")

        emails = [row["email"] for row in response.json()]
        self.assertEqual(emails, ["a@example.com"])

    def test_list_excludes_inactive_invitations(self):
        active = self.make_invitation(email="active@example.com")
        inactive = self.make_invitation(email="inactive@example.com")
        inactive.is_active = False
        inactive.save(update_fields=["is_active"])

        self.authenticate(self.admin_a)
        response = self.client.get("/api/schools/invitations/")

        emails = [row["email"] for row in response.json()]
        self.assertEqual(emails, ["active@example.com"])

    # -- accept ----------------------------------------------------------

    def test_accept_success_attaches_teacher_to_school(self):
        invitation = self.make_invitation(email="prospective@example.com")
        self.authenticate(self.prospective_teacher)

        response = self.client.post(
            "/api/schools/invitations/accept/",
            {"invitation_code": invitation.invitation_code},
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["school_name"], "School A")

        self.prospective_teacher.refresh_from_db()
        self.assertEqual(self.prospective_teacher.role, Role.TEACHER)
        self.assertEqual(self.prospective_teacher.school_id, self.school_a.id)

        invitation.refresh_from_db()
        self.assertIsNotNone(invitation.accepted_at)
        self.assertFalse(invitation.is_active)

    def test_accept_invalid_code_is_rejected(self):
        self.authenticate(self.prospective_teacher)

        response = self.client.post(
            "/api/schools/invitations/accept/",
            {"invitation_code": "NOTAREAL"},
            format="json",
        )

        self.assertEqual(response.status_code, 400)

    def test_accept_expired_invitation_is_rejected(self):
        invitation = self.make_invitation(email="prospective@example.com")
        invitation.expires_at = timezone.now() - timedelta(days=1)
        invitation.save(update_fields=["expires_at"])

        self.authenticate(self.prospective_teacher)
        response = self.client.post(
            "/api/schools/invitations/accept/",
            {"invitation_code": invitation.invitation_code},
            format="json",
        )

        self.assertEqual(response.status_code, 400)
        self.prospective_teacher.refresh_from_db()
        self.assertIsNone(self.prospective_teacher.school_id)

    def test_accept_inactive_invitation_is_rejected(self):
        invitation = self.make_invitation(email="prospective@example.com")
        invitation.is_active = False
        invitation.save(update_fields=["is_active"])

        self.authenticate(self.prospective_teacher)
        response = self.client.post(
            "/api/schools/invitations/accept/",
            {"invitation_code": invitation.invitation_code},
            format="json",
        )

        self.assertEqual(response.status_code, 400)

    def test_duplicate_acceptance_is_rejected(self):
        invitation = self.make_invitation(email="prospective@example.com")
        self.authenticate(self.prospective_teacher)
        self.client.post(
            "/api/schools/invitations/accept/",
            {"invitation_code": invitation.invitation_code},
            format="json",
        )

        second_attempt = self.client.post(
            "/api/schools/invitations/accept/",
            {"invitation_code": invitation.invitation_code},
            format="json",
        )

        self.assertEqual(second_attempt.status_code, 400)

    def test_teacher_already_in_a_different_school_cannot_accept(self):
        invitation = self.make_invitation(
            school=self.school_b, invited_by=self.admin_b, email="teacher-a@example.com"
        )
        self.authenticate(self.teacher_a)

        response = self.client.post(
            "/api/schools/invitations/accept/",
            {"invitation_code": invitation.invitation_code},
            format="json",
        )

        self.assertEqual(response.status_code, 400)
        self.teacher_a.refresh_from_db()
        self.assertEqual(self.teacher_a.school_id, self.school_a.id)

    def test_accepting_an_invitation_to_the_same_school_again_is_allowed(self):
        """"School assignment absent or valid" - already being on *this*
        school is not the conflict the rule exists to catch."""
        invitation = self.make_invitation(email="teacher-a@example.com")
        self.authenticate(self.teacher_a)

        response = self.client.post(
            "/api/schools/invitations/accept/",
            {"invitation_code": invitation.invitation_code},
            format="json",
        )

        self.assertEqual(response.status_code, 200)

    def test_parent_role_cannot_accept_invitation(self):
        invitation = self.make_invitation(email="parent@example.com")
        self.authenticate(self.parent)

        response = self.client.post(
            "/api/schools/invitations/accept/",
            {"invitation_code": invitation.invitation_code},
            format="json",
        )

        self.assertEqual(response.status_code, 400)
        self.parent.refresh_from_db()
        self.assertEqual(self.parent.role, Role.PARENT)

    # -- reset / deactivate ----------------------------------------------

    def test_admin_can_reset_invitation_code(self):
        invitation = self.make_invitation()
        old_code = invitation.invitation_code
        self.authenticate(self.admin_a)

        response = self.client.post(f"/api/schools/invitations/{invitation.id}/reset/")

        self.assertEqual(response.status_code, 200)
        invitation.refresh_from_db()
        self.assertNotEqual(invitation.invitation_code, old_code)
        # History is kept: same row, same invited_by/created_at.
        self.assertEqual(invitation.invited_by_id, self.admin_a.id)

    def test_reset_is_denied_for_a_different_schools_admin(self):
        invitation = self.make_invitation()
        self.authenticate(self.admin_b)

        response = self.client.post(f"/api/schools/invitations/{invitation.id}/reset/")

        self.assertEqual(response.status_code, 404)

    def test_reset_is_rejected_for_an_inactive_invitation(self):
        invitation = self.make_invitation()
        invitation.is_active = False
        invitation.save(update_fields=["is_active"])
        self.authenticate(self.admin_a)

        response = self.client.post(f"/api/schools/invitations/{invitation.id}/reset/")

        self.assertEqual(response.status_code, 400)

    def test_admin_can_deactivate_invitation(self):
        invitation = self.make_invitation()
        self.authenticate(self.admin_a)

        response = self.client.post(
            f"/api/schools/invitations/{invitation.id}/deactivate/"
        )

        self.assertEqual(response.status_code, 200)
        invitation.refresh_from_db()
        self.assertFalse(invitation.is_active)
        # Soft revoke only - the row survives.
        self.assertTrue(TeacherInvitation.objects.filter(id=invitation.id).exists())

    def test_deactivate_is_denied_for_a_different_schools_admin(self):
        invitation = self.make_invitation()
        self.authenticate(self.admin_b)

        response = self.client.post(
            f"/api/schools/invitations/{invitation.id}/deactivate/"
        )

        self.assertEqual(response.status_code, 404)
        invitation.refresh_from_db()
        self.assertTrue(invitation.is_active)

    # -- one active invitation per (school, email) ------------------------

    def test_duplicate_active_invitation_for_same_school_and_email_is_rejected(self):
        self.make_invitation(email="repeat@example.com")
        self.authenticate(self.admin_a)

        response = self.client.post(
            "/api/schools/invitations/",
            {"email": "repeat@example.com"},
            format="json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(
            TeacherInvitation.objects.filter(
                school=self.school_a, email="repeat@example.com", is_active=True
            ).count(),
            1,
        )

    def test_a_new_active_invitation_is_allowed_once_the_old_one_is_inactive(self):
        """History (the old, no-longer-active row) must not block a
        second, genuine invitation to the same address later."""
        old = self.make_invitation(email="repeat@example.com")
        old.is_active = False
        old.save(update_fields=["is_active"])
        self.authenticate(self.admin_a)

        response = self.client.post(
            "/api/schools/invitations/",
            {"email": "repeat@example.com"},
            format="json",
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(
            TeacherInvitation.objects.filter(
                school=self.school_a, email="repeat@example.com"
            ).count(),
            2,
        )

    def test_model_level_constraint_blocks_two_active_rows_directly(self):
        """Proves the guarantee lives in the database, not only in the
        serializer - the same insert attempted straight through the ORM,
        bypassing the API/serializer validation entirely, must still
        fail."""
        self.make_invitation(email="direct@example.com")

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                self.make_invitation(email="direct@example.com")

    def test_model_level_constraint_allows_an_inactive_duplicate(self):
        self.make_invitation(email="direct2@example.com", is_active=False)

        # Should not raise: the first row is inactive, so a second active
        # row for the same (school, email) is not a conflict.
        second = self.make_invitation(email="direct2@example.com")
        self.assertTrue(second.is_active)
