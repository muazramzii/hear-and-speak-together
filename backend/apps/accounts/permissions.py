"""Role-based permissions.

Kept as small, composable classes so views declare intent rather than
re-checking `request.user.role` inline.
"""

from rest_framework.permissions import BasePermission

from .models import Role


class IsStudent(BasePermission):
    """Only a learner may practise and record attempts."""

    message = "Only student accounts can do this."

    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and user.role == Role.STUDENT)


class IsParentOrTeacher(BasePermission):
    """Guardians and educators share the monitoring views."""

    message = "Only parent or teacher accounts can do this."

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and user.role in {Role.PARENT, Role.TEACHER}
        )
