from rest_framework import serializers

from .models import Classroom, ClassroomMembership, ClassroomStaffRole, School, TeacherInvitation


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


class TeacherInvitationSerializer(serializers.ModelSerializer):
    """Read shape. Deliberately exposes no raw foreign-key ids for
    `school`/`invited_by` - `school_name`/`invited_by_email` say
    everything an admin needs without handing out sequential database
    ids for rows this account cannot otherwise browse. `id` itself stays
    - it is how this same admin targets the reset/deactivate actions on
    this exact invitation, and it is only ever visible to the same-school
    admin the queryset already scopes this to.
    """

    school_name = serializers.CharField(source="school.name", read_only=True)
    invited_by_email = serializers.EmailField(
        source="invited_by.email", read_only=True
    )

    class Meta:
        model = TeacherInvitation
        fields = [
            "id",
            "email",
            "invitation_code",
            "school_name",
            "invited_by_email",
            "expires_at",
            "accepted_at",
            "is_active",
            "created_at",
        ]
        read_only_fields = fields


class TeacherInvitationCreateSerializer(serializers.ModelSerializer):
    """Input shape for creating an invitation: an email address, nothing
    else. `school` and `invited_by` are always taken from the
    authenticated admin's own request, never from the client.

    The `validate` check below is a friendly 400 for the common case; the
    database's conditional `UniqueConstraint` on `(school, email)` where
    `is_active=True` is the actual guarantee, catching the rare
    concurrent-request race this single-request check cannot.
    """

    class Meta:
        model = TeacherInvitation
        fields = ["email"]

    def validate_email(self, value):
        return value.strip().lower()

    def validate(self, attrs):
        request = self.context.get("request")
        school = getattr(request.user, "school", None) if request else None
        if (
            school is not None
            and TeacherInvitation.objects.filter(
                school=school, email=attrs["email"], is_active=True
            ).exists()
        ):
            raise serializers.ValidationError(
                "There is already an active invitation for this email at "
                "this school."
            )
        return attrs


class TeacherInvitationAcceptSerializer(serializers.Serializer):
    """Input shape for `/api/schools/invitations/accept/` - just the code
    the teacher was given."""

    invitation_code = serializers.CharField(max_length=8)

    def validate_invitation_code(self, value):
        return value.strip().upper()


class ClassroomMembershipSerializer(serializers.ModelSerializer):
    """Read shape for one row of a classroom's staff list. No raw
    `classroom` id - the membership is always read in the context of one
    already-identified classroom, never browsed on its own."""

    teacher_id = serializers.IntegerField(source="teacher.id", read_only=True)
    teacher_name = serializers.CharField(source="teacher.name", read_only=True)
    teacher_email = serializers.EmailField(source="teacher.email", read_only=True)

    class Meta:
        model = ClassroomMembership
        fields = [
            "teacher_id",
            "teacher_name",
            "teacher_email",
            "role",
            "created_at",
        ]
        read_only_fields = fields


class ClassroomMembershipWriteSerializer(serializers.Serializer):
    """Input shape for `POST /api/classrooms/{id}/teachers/`."""

    teacher_id = serializers.IntegerField()
    role = serializers.ChoiceField(
        choices=ClassroomStaffRole.choices, default=ClassroomStaffRole.LEAD_TEACHER
    )


class ClassroomStudentMoveSerializer(serializers.Serializer):
    """Input shape for `POST /api/classrooms/{id}/students/`."""

    profile_id = serializers.IntegerField()


class ClassroomSerializer(serializers.ModelSerializer):
    """List/summary read shape - everything except the staff roster,
    which only the detail view includes (a list of many classrooms has no
    use for each one's full staff list, and it would mean an extra query
    per row)."""

    student_count = serializers.IntegerField(source="students.count", read_only=True)

    class Meta:
        model = Classroom
        fields = [
            "id",
            "name",
            "classroom_code",
            "is_active",
            "student_count",
            "created_at",
        ]
        read_only_fields = fields


class ClassroomDetailSerializer(ClassroomSerializer):
    """`GET /api/classrooms/{id}/` - the list shape plus the assigned
    staff list the brief calls for."""

    staff = ClassroomMembershipSerializer(
        source="staff_memberships", many=True, read_only=True
    )

    class Meta(ClassroomSerializer.Meta):
        fields = ClassroomSerializer.Meta.fields + ["staff"]
        read_only_fields = fields


class ClassroomWriteSerializer(serializers.ModelSerializer):
    """Create/update shape. `school` and `classroom_code` are never
    accepted from the client - school comes from the authenticated
    admin's own account, and the code is always generated, never chosen."""

    class Meta:
        model = Classroom
        fields = ["id", "name", "is_active"]

    def validate_name(self, value):
        name = value.strip()
        if not name:
            raise serializers.ValidationError("A classroom needs a name.")
        return name
