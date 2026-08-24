"""Who may look at which learner's data.

Shared by every supervisor-facing view (`progress`, `practice`) so the rule
lives in exactly one place: a profile is visible to its owner and to anyone
holding a `StudentLink` to it, and to no one else.
"""

from django.db.models import Q

from .models import Profile


def accessible_profiles(user):
    """Profiles this user may look at.

    Two routes in: profiles they own (their own children), and profiles a
    teacher has been linked to. Anything else is invisible, so a supervisor
    cannot browse other families by guessing ids.

    Imports `StudentLink` lazily to avoid a circular import - that model
    lives in `apps.progress`, which already imports from `apps.practice`
    and `apps.profiles`.
    """
    from apps.progress.models import StudentLink

    linked_ids = StudentLink.objects.filter(supervisor=user).values_list(
        "profile_id", flat=True
    )
    return Profile.objects.filter(
        Q(owner=user) | Q(pk__in=linked_ids)
    ).select_related("practice_language")
