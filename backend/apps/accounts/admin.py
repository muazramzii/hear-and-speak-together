from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.forms import AdminPasswordChangeForm
from django.utils.translation import gettext_lazy as _

from .models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    """Admin for the email-based user model.

    `BaseUserAdmin` assumes a `username` field, so the fieldsets and the
    ordering both have to be redefined.
    """

    change_password_form = AdminPasswordChangeForm

    list_display = ["email", "name", "role", "preferred_language", "is_active", "created_at"]
    list_filter = ["role", "preferred_language", "is_active", "is_staff", "created_at"]
    search_fields = ["email", "name"]
    ordering = ["-created_at"]
    readonly_fields = ["created_at", "updated_at", "last_login"]

    fieldsets = [
        (None, {"fields": ["email", "password"]}),
        (_("Profile"), {"fields": ["name", "role", "preferred_language"]}),
        (
            _("Permissions"),
            {
                "fields": [
                    "is_active",
                    "is_staff",
                    "is_superuser",
                    "groups",
                    "user_permissions",
                ]
            },
        ),
        (_("Important dates"), {"fields": ["last_login", "created_at", "updated_at"]}),
    ]

    add_fieldsets = [
        (
            None,
            {
                "classes": ["wide"],
                "fields": [
                    "email",
                    "name",
                    "role",
                    "preferred_language",
                    "password1",
                    "password2",
                ],
            },
        ),
    ]
