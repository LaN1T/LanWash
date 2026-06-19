"""assigned_washer_junction_table

Revision ID: 03d0cab39757
Revises: e695ee8f432b
Create Date: 2026-06-19 19:11:48.635764

"""
import json
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import context, op

# revision identifiers, used by Alembic.
revision: str = "03d0cab39757"
down_revision: Union[str, Sequence[str], None] = "e695ee8f432b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "appointment_washers",
        sa.Column("appointmentId", sa.String(), nullable=False),
        sa.Column("washerUsername", sa.String(), nullable=False),
        sa.ForeignKeyConstraint(
            ["appointmentId"],
            ["appointments.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("appointmentId", "washerUsername"),
    )
    op.create_index(
        "ix_appointment_washers_washer",
        "appointment_washers",
        ["washerUsername"],
        unique=False,
    )

    if context.is_offline_mode():
        dialect = op.get_context().dialect.name
        if dialect == "postgresql":
            op.execute(
                sa.text(
                    'INSERT INTO appointment_washers ("appointmentId", "washerUsername") '
                    'SELECT a.id, j.value '
                    'FROM appointments a, json_array_elements_text(a."assignedWasher"::json) j '
                    "WHERE a.\"assignedWasher\" IS NOT NULL "
                    "AND a.\"assignedWasher\" NOT IN ('', '[]')"
                )
            )
        elif dialect == "sqlite":
            op.execute(
                sa.text(
                    'INSERT INTO appointment_washers ("appointmentId", "washerUsername") '
                    'SELECT a.id, j.value '
                    'FROM appointments a, json_each(a."assignedWasher") j '
                    "WHERE a.\"assignedWasher\" IS NOT NULL "
                    "AND a.\"assignedWasher\" NOT IN ('', '[]')"
                )
            )
    else:
        conn = op.get_bind()
        rows = conn.execute(
            sa.text('SELECT id, "assignedWasher" FROM appointments')
        ).fetchall()
        for appt_id, raw in rows:
            if not raw or raw == "[]":
                continue
            try:
                usernames = json.loads(raw)
            except Exception:
                continue
            if not isinstance(usernames, list):
                continue
            for username in usernames:
                conn.execute(
                    sa.text(
                        'INSERT INTO appointment_washers ("appointmentId", "washerUsername") '
                        "VALUES (:aid, :user) ON CONFLICT DO NOTHING"
                    ),
                    {"aid": appt_id, "user": username},
                )

    op.drop_index("ix_appointments_assigned_washer", table_name="appointments")
    op.drop_column("appointments", "assignedWasher")


def downgrade() -> None:
    op.add_column(
        "appointments",
        sa.Column(
            "assignedWasher",
            sa.String(),
            nullable=False,
            server_default="[]",
        ),
    )
    op.create_index(
        "ix_appointments_assigned_washer",
        "appointments",
        ["assignedWasher"],
        unique=False,
    )

    conn = op.get_bind()
    rows = conn.execute(
        sa.text('SELECT "appointmentId", "washerUsername" FROM appointment_washers')
    ).fetchall()
    grouped: dict[str, list[str]] = {}
    for aid, user in rows:
        grouped.setdefault(aid, []).append(user)
    for aid, users in grouped.items():
        conn.execute(
            sa.text(
                'UPDATE appointments SET "assignedWasher" = :val WHERE id = :aid'
            ),
            {"val": json.dumps(users, ensure_ascii=False), "aid": aid},
        )

    op.drop_index("ix_appointment_washers_washer", table_name="appointment_washers")
    op.drop_table("appointment_washers")
