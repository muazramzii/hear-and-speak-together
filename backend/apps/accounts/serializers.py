"""Serializers for registration, login and the current-user endpoint."""

from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from .models import LanguageCode, Role

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    """The public shape of a user. Never includes the password hash."""

    class Meta:
        model = User
        fields = [
            "id",
            "name",
            "email",
            "role",
            "preferred_language",
            "created_at",
        ]
        read_only_fields = ["id", "email", "role", "created_at"]


class RegisterSerializer(serializers.ModelSerializer):
    """Creates an account.

    `role` is accepted at registration because a parent or teacher signs up
    for themselves. Staff and superuser flags are deliberately absent - they
    can only be granted through the Django admin.
    """

    password = serializers.CharField(
        write_only=True,
        min_length=8,
        style={"input_type": "password"},
        trim_whitespace=False,
    )
    password_confirm = serializers.CharField(
        write_only=True,
        style={"input_type": "password"},
        trim_whitespace=False,
    )
    role = serializers.ChoiceField(choices=Role.choices, default=Role.STUDENT)
    preferred_language = serializers.ChoiceField(
        choices=LanguageCode.choices, default=LanguageCode.ENGLISH
    )

    class Meta:
        model = User
        fields = [
            "id",
            "name",
            "email",
            "password",
            "password_confirm",
            "role",
            "preferred_language",
        ]
        read_only_fields = ["id"]

    def validate_email(self, value):
        email = value.lower().strip()
        if User.objects.filter(email=email).exists():
            raise serializers.ValidationError(
                "An account with this email already exists."
            )
        return email

    def validate(self, attrs):
        if attrs["password"] != attrs.pop("password_confirm"):
            raise serializers.ValidationError(
                {"password_confirm": "The two passwords do not match."}
            )

        # Run Django's configured password validators, translating the error
        # so DRF reports it against the right field.
        try:
            validate_password(attrs["password"])
        except DjangoValidationError as exc:
            raise serializers.ValidationError({"password": list(exc.messages)})

        return attrs

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)


class LoginSerializer(TokenObtainPairSerializer):
    """Issues an access/refresh pair and returns the user alongside them.

    Bundling the user saves the client an extra round trip to `/auth/me/`
    immediately after signing in.
    """

    username_field = User.USERNAME_FIELD

    def validate(self, attrs):
        # Normalise so "Amir@Example.com" logs in the same account as
        # "amir@example.com".
        if self.username_field in attrs:
            attrs[self.username_field] = attrs[self.username_field].lower().strip()

        data = super().validate(attrs)
        data["user"] = UserSerializer(self.user).data
        return data


class UpdateProfileSerializer(serializers.ModelSerializer):
    """Lets a signed-in user change their display name and language.

    Email and role are intentionally immutable here: changing either has
    security or data-ownership consequences that belong in the admin.
    """

    preferred_language = serializers.ChoiceField(choices=LanguageCode.choices)

    class Meta:
        model = User
        fields = ["name", "preferred_language"]
