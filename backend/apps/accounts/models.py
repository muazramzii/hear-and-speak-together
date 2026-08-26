"""User model for Hear & Speak Together.

Children, parents and teachers all share one table and are distinguished by
`role`. A separate table per role would duplicate authentication logic for no
benefit at this scale.
"""

import uuid

from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.db import models
from django.utils import timezone
from django.utils.translation import gettext_lazy as _

from .managers import UserManager


class Role(models.TextChoices):
    """Who the account belongs to. Drives permissions and which app shell
    the mobile client shows after sign-in."""

    STUDENT = "STUDENT", _("Student")
    PARENT = "PARENT", _("Parent")
    TEACHER = "TEACHER", _("Teacher")
    SCHOOL_ADMIN = "SCHOOL_ADMIN", _("School admin")


class LanguageCode(models.TextChoices):
    """The languages the application teaches.

    These codes are the single source of truth: the `Language` model added in
    a later phase reuses them, so a user's preference and the lesson content
    can never drift apart.
    """

    ENGLISH = "en", _("English")
    MALAY = "ms", _("Bahasa Melayu")


class User(AbstractBaseUser, PermissionsMixin):
    """Authentication is by email; there is no separate username.

    Asking a child to remember a username *and* a password is friction we do
    not need, and an email address is already unique.
    """

    name = models.CharField(_("name"), max_length=120)
    email = models.EmailField(_("email address"), unique=True)

    # A stable, non-sequential public reference for this account. The
    # integer `id` primary key must never appear in an API request or
    # response - anywhere a client needs to name a specific user (Phase 6
    # classroom staff assignment, and any future case), this is the value
    # that identifies them instead.
    public_id = models.UUIDField(
        _("public id"), default=uuid.uuid4, unique=True, editable=False
    )

    role = models.CharField(
        _("role"),
        max_length=16,
        choices=Role.choices,
        default=Role.STUDENT,
    )
    preferred_language = models.CharField(
        _("preferred language"),
        max_length=8,
        choices=LanguageCode.choices,
        default=LanguageCode.ENGLISH,
        help_text=_("Language the app opens in and practises by default."),
    )

    # Phase 6: which School this account belongs to, if any. Null for
    # every account that predates multi-tenancy, and for any account not
    # affiliated with a school (a stand-alone parent, or a teacher who
    # only follows students by share code - see apps.progress.StudentLink).
    school = models.ForeignKey(
        "schools.School",
        on_delete=models.SET_NULL,
        related_name="staff",
        verbose_name=_("school"),
        null=True,
        blank=True,
    )

    # Django admin / permissions plumbing.
    is_active = models.BooleanField(_("active"), default=True)
    is_staff = models.BooleanField(_("staff status"), default=False)

    created_at = models.DateTimeField(_("created at"), default=timezone.now)
    updated_at = models.DateTimeField(_("updated at"), auto_now=True)

    objects = UserManager()

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["name"]

    class Meta:
        verbose_name = _("user")
        verbose_name_plural = _("users")
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["role"]),
        ]

    def __str__(self):
        return f"{self.name} <{self.email}>"

    def save(self, *args, **kwargs):
        # Emails are case-insensitive in practice; storing them lowercased
        # keeps the unique constraint honest.
        self.email = self.email.lower().strip()
        return super().save(*args, **kwargs)

    @property
    def is_student(self):
        return self.role == Role.STUDENT

    @property
    def is_parent(self):
        return self.role == Role.PARENT

    @property
    def is_teacher(self):
        return self.role == Role.TEACHER

    @property
    def supervises_students(self):
        """Parents and teachers both monitor students and share those views."""
        return self.role in {Role.PARENT, Role.TEACHER}
