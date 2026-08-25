from django.contrib import admin

from .models import Classroom, ClassroomMembership, School


class ClassroomMembershipInline(admin.TabularInline):
    model = ClassroomMembership
    extra = 0
    autocomplete_fields = ["teacher"]


@admin.register(School)
class SchoolAdmin(admin.ModelAdmin):
    list_display = ["name", "admin", "is_active", "created_at"]
    list_filter = ["is_active", "created_at"]
    search_fields = ["name", "admin__email", "admin__name"]
    readonly_fields = ["created_at", "updated_at"]
    autocomplete_fields = ["admin"]


@admin.register(Classroom)
class ClassroomAdmin(admin.ModelAdmin):
    list_display = ["name", "school", "classroom_code", "is_active"]
    list_filter = ["is_active", "school"]
    search_fields = ["name", "classroom_code"]
    readonly_fields = ["classroom_code", "created_at", "updated_at"]
    list_select_related = ["school"]
    autocomplete_fields = ["school"]
    inlines = [ClassroomMembershipInline]


@admin.register(ClassroomMembership)
class ClassroomMembershipAdmin(admin.ModelAdmin):
    list_display = ["teacher", "classroom", "role", "created_at"]
    list_filter = ["role"]
    search_fields = ["teacher__email", "teacher__name", "classroom__name"]
    list_select_related = ["teacher", "classroom"]
    autocomplete_fields = ["teacher", "classroom"]
