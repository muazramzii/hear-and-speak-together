from django.contrib import admin

from .models import PracticeAttempt, PronunciationDebugAttempt


@admin.register(PracticeAttempt)
class PracticeAttemptAdmin(admin.ModelAdmin):
    list_display = [
        "reference_text",
        "profile",
        "locale",
        "display_score",
        "points_awarded",
        "created_at",
    ]
    list_filter = ["language_code", "created_at"]
    search_fields = ["reference_text", "recognized_text", "profile__name"]
    date_hierarchy = "created_at"
    list_select_related = ["profile", "word"]

    # Attempts are an audit trail of what a child actually said and what the
    # pronunciation engine actually scored. Editing them by hand would
    # corrupt the analytics built on top.
    readonly_fields = [field.name for field in PracticeAttempt._meta.fields]

    def has_add_permission(self, request):
        return False

    @admin.display(description="Score")
    def display_score(self, attempt):
        return attempt.display_score


@admin.register(PronunciationDebugAttempt)
class PronunciationDebugAttemptAdmin(admin.ModelAdmin):
    list_display = [
        "reference_text",
        "recognized_text",
        "language_code",
        "pronunciation_score",
        "processing_time_ms",
        "created_by",
        "created_at",
    ]
    list_filter = ["language_code", "created_at"]
    search_fields = ["reference_text", "recognized_text", "created_by__email"]
    date_hierarchy = "created_at"
    list_select_related = ["created_by"]

    # A log of engine runs, not editable data - same rationale as
    # PracticeAttempt above.
    readonly_fields = [
        field.name for field in PronunciationDebugAttempt._meta.fields
    ]

    def has_add_permission(self, request):
        return False
