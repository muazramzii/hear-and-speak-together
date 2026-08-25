from rest_framework import serializers

from .models import School


class SchoolSerializer(serializers.ModelSerializer):
    """Read shape for `/api/schools/`."""

    admin_email = serializers.EmailField(source="admin.email", read_only=True)

    class Meta:
        model = School
        fields = [
            "id",
            "name",
            "logo",
            "admin_email",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields


class SchoolWriteSerializer(serializers.ModelSerializer):
    """Create/update shape.

    `admin` is never accepted from the client - a school always belongs to
    whichever SCHOOL_ADMIN created it (set by the view from
    `request.user`), never to an admin id supplied in the request body.

    The Phase 6 brief also lists an "address" field as editable, but no
    such field exists on `School` yet (Task 2 only added `school`/
    `classroom` FKs) - adding one is a model change this task is not
    scoped to make, since it would require a migration this task
    explicitly must not produce. Omitted here rather than faked.
    """

    class Meta:
        model = School
        fields = ["id", "name", "logo", "is_active"]

    def validate_name(self, value):
        name = value.strip()
        if not name:
            raise serializers.ValidationError("A school needs a name.")
        return name
