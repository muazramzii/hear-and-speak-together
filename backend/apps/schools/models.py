"""School and classroom hierarchy for the Phase 6 multi-tenant platform.

A School is the tenant boundary: every classroom, and every teacher or
student scoped to a school, hangs off exactly one School row. Staffing a
classroom is many-to-many (`ClassroomMembership`), not a single FK - a real
special-education classroom often has a lead teacher plus an assistant
and/or a speech therapist attached to it at once.

Nothing here replaces the existing single-teacher share-code linking in
`apps.progress.StudentLink` - that keeps working unchanged for teachers who
are not part of a school. This hierarchy is additive: a teacher gains
classroom-scoped access on top of whatever individual students they already
follow, rather than the two mechanisms competing.
"""

import secrets

from django.conf import settings
from django.db import models
from django.utils.translation import gettext_lazy as _

# Excludes characters a teacher or admin would misread aloud: 0/O, 1/I/L.
_CLASSROOM_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
_CLASSROOM_CODE_LENGTH = 6


def generate_classroom_code():
    """A short code printable on a roster sheet - not a login credential,
    just a human-friendly way to refer to a classroom."""
    return "".join(
        secrets.choice(_CLASSROOM_CODE_ALPHABET)
        for _ in range(_CLASSROOM_CODE_LENGTH)
    )


class School(models.Model):
    """The tenant. `admin` is the account that manages it - see
    `Role.SCHOOL_ADMIN` on the `User` model, added alongside this app's
    permission layer."""

    name = models.CharField(_("name"), max_length=150)
    logo = models.ImageField(
        _("logo"), upload_to="school_logos/", null=True, blank=True
    )
    admin = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="administered_schools",
        verbose_name=_("admin"),
        help_text=_("The School Admin account that owns this school."),
    )
    is_active = models.BooleanField(_("active"), default=True)

    created_at = models.DateTimeField(_("created at"), auto_now_add=True)
    updated_at = models.DateTimeField(_("updated at"), auto_now=True)

    class Meta:
        verbose_name = _("school")
        verbose_name_plural = _("schools")
        ordering = ["name"]

    def __str__(self):
        return self.name


class Classroom(models.Model):
    """A group of students within a `School`.

    Staffing is a separate `ClassroomMembership` model, not a direct FK
    here: a real special-education classroom routinely has more than one
    adult attached to it (a lead teacher plus an assistant and/or a
    speech therapist), so the relationship is many-to-many, not
    one-to-one. A classroom can exist with no staff assigned yet -
    Classroom Management lists "create classroom" and "assign teacher"
    as separate actions.
    """

    school = models.ForeignKey(
        School,
        on_delete=models.CASCADE,
        related_name="classrooms",
        verbose_name=_("school"),
    )
    name = models.CharField(_("name"), max_length=120)
    classroom_code = models.CharField(
        _("classroom code"),
        max_length=12,
        unique=True,
        default=generate_classroom_code,
        help_text=_(
            "Shown to the admin for rosters and handouts; not a login "
            "credential."
        ),
    )
    is_active = models.BooleanField(_("active"), default=True)

    created_at = models.DateTimeField(_("created at"), auto_now_add=True)
    updated_at = models.DateTimeField(_("updated at"), auto_now=True)

    class Meta:
        verbose_name = _("classroom")
        verbose_name_plural = _("classrooms")
        ordering = ["school", "name"]
        constraints = [
            models.UniqueConstraint(
                fields=["school", "name"],
                name="unique_classroom_name_per_school",
            )
        ]
        indexes = [
            models.Index(fields=["school"]),
        ]

    def __str__(self):
        return f"{self.name} ({self.school.name})"


class ClassroomStaffRole(models.TextChoices):
    """Who a staff member is to a classroom. Deliberately not tied to
    `accounts.Role` - a therapist may or may not have a TEACHER account
    role, and this is about their function in *this* classroom, not
    their account type."""

    LEAD_TEACHER = "LEAD_TEACHER", _("Lead teacher")
    ASSISTANT = "ASSISTANT", _("Assistant")
    THERAPIST = "THERAPIST", _("Therapist")


class ClassroomMembership(models.Model):
    """One staff member's assignment to one classroom.

    A teacher can appear on several classrooms (e.g. an assistant who
    floats between two rooms), and a classroom can have several staff -
    hence a junction model rather than a FK on either side.
    """

    classroom = models.ForeignKey(
        Classroom,
        on_delete=models.CASCADE,
        related_name="staff_memberships",
        verbose_name=_("classroom"),
    )
    teacher = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="classroom_memberships",
        verbose_name=_("teacher"),
    )
    role = models.CharField(
        _("role"),
        max_length=16,
        choices=ClassroomStaffRole.choices,
        default=ClassroomStaffRole.LEAD_TEACHER,
    )

    created_at = models.DateTimeField(_("created at"), auto_now_add=True)

    class Meta:
        verbose_name = _("classroom membership")
        verbose_name_plural = _("classroom memberships")
        ordering = ["classroom", "role"]
        constraints = [
            models.UniqueConstraint(
                fields=["classroom", "teacher"],
                name="unique_membership_per_classroom",
            )
        ]
        indexes = [
            models.Index(fields=["teacher"]),
        ]

    def __str__(self):
        return f"{self.teacher.name} - {self.classroom.name} ({self.role})"
