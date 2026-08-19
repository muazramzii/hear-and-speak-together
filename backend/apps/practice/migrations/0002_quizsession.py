import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("practice", "0001_initial"),
        ("profiles", "0001_initial"),
        ("content", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="QuizSession",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                (
                    "mode",
                    models.CharField(
                        choices=[("LISTEN", "Listen"), ("QUIZ", "Quiz")],
                        max_length=16,
                        verbose_name="mode",
                    ),
                ),
                (
                    "correct_count",
                    models.PositiveIntegerField(
                        default=0, verbose_name="correct answers"
                    ),
                ),
                (
                    "total_rounds",
                    models.PositiveIntegerField(
                        default=0, verbose_name="total rounds"
                    ),
                ),
                (
                    "points_awarded",
                    models.PositiveIntegerField(
                        default=0, verbose_name="points awarded"
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "lesson",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="quiz_sessions",
                        to="content.lesson",
                    ),
                ),
                (
                    "profile",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="quiz_sessions",
                        to="profiles.profile",
                    ),
                ),
            ],
            options={
                "verbose_name": "quiz session",
                "verbose_name_plural": "quiz sessions",
                "ordering": ["-created_at"],
            },
        ),
        migrations.AddIndex(
            model_name="quizsession",
            index=models.Index(
                fields=["profile", "-created_at"],
                name="practice_qu_profile_c3865d_idx",
            ),
        ),
    ]
