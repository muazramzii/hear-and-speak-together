import django_filters

from .models import Classroom


class ClassroomFilter(django_filters.FilterSet):
    """Query-param filters for `GET /api/classrooms/`.

    `active`/`teacher`/`search` are the names the Phase 6 brief specifies
    for the client - `active` maps onto the model's `is_active` field,
    and `teacher`/`search` aren't real columns at all (a membership
    lookup and a name substring match respectively), which is exactly
    what a `FilterSet` is for instead of hand-rolling this in the view.
    """

    active = django_filters.BooleanFilter(field_name="is_active")
    teacher = django_filters.NumberFilter(
        field_name="staff_memberships__teacher_id"
    )
    search = django_filters.CharFilter(field_name="name", lookup_expr="icontains")

    class Meta:
        model = Classroom
        fields = ["active", "teacher", "search"]
