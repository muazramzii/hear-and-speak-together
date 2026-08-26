import uuid

from django.db import migrations, models


def generate_public_ids(apps, schema_editor):
    """Backfill a distinct UUID for every existing row before the unique
    constraint is applied in the next step. A single shared default would
    violate uniqueness the moment a second row tried to use it."""
    User = apps.get_model("accounts", "User")
    for user in User.objects.all().only("id"):
        user.public_id = uuid.uuid4()
        user.save(update_fields=["public_id"])


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0002_user_school_alter_user_role"),
    ]

    operations = [
        migrations.AddField(
            model_name="user",
            name="public_id",
            field=models.UUIDField(
                default=uuid.uuid4,
                editable=False,
                null=True,
                verbose_name="public id",
            ),
        ),
        migrations.RunPython(generate_public_ids, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="user",
            name="public_id",
            field=models.UUIDField(
                default=uuid.uuid4,
                editable=False,
                unique=True,
                verbose_name="public id",
            ),
        ),
    ]
