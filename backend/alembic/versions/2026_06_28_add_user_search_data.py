"""Add searchData JSON column to users for raw phone/email/car_number indexing.

Revision ID: 2026_06_28_add_user_search_data
Revises: 834b3fb6eb66
Create Date: 2026-06-28 21:30:00.000000
"""

import sqlalchemy as sa
from sqlalchemy import inspect
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "2026_06_28_add_user_search_data"
down_revision = "834b3fb6eb66"
branch_labels = None
depends_on = None


def _column_exists(table: str, column: str) -> bool:
    """Check whether a column exists in the given table."""
    bind = op.get_bind()
    return column in {c["name"] for c in inspect(bind).get_columns(table)}


def _digits(value: str | None) -> str:
    """Return only digits from a string."""
    return "".join(ch for ch in (value or "") if ch.isdigit())


def _backfill_search_data(conn) -> None:
    """Fill searchData with raw phone digits, lowercased email and car_number digits."""
    users = sa.table(
        "users",
        sa.column("id", sa.Integer),
        sa.column("phone", sa.String),
        sa.column("email", sa.String),
        sa.column("carNumber", sa.String),
        sa.column("searchData", sa.JSON),
    )

    rows = conn.execute(
        sa.select(users.c.id, users.c.phone, users.c.email, users.c.carNumber)
    )
    for row in rows:
        phone_digits = _digits(row.phone)
        email_clean = (row.email or "").lower().strip()
        car_number_digits = _digits(row.carNumber)
        conn.execute(
            sa.update(users)
            .where(users.c.id == row.id)
            .values(
                searchData={
                    "phone": phone_digits,
                    "email": email_clean,
                    "car_number": car_number_digits,
                }
            )
        )


def _drop_column(table: str, column: str) -> None:
    """Drop a column, using batch_alter_table for SQLite compatibility."""
    if op.get_bind().dialect.name == "sqlite":
        with op.batch_alter_table(table) as batch_op:
            batch_op.drop_column(column)
    else:
        op.drop_column(table, column)


def upgrade() -> None:
    if _column_exists("users", "searchData"):
        return

    conn = op.get_bind()
    dialect = conn.dialect.name

    json_type = postgresql.JSONB() if dialect == "postgresql" else sa.JSON()
    op.add_column(
        "users",
        sa.Column(
            "searchData",
            json_type,
            nullable=True,
            server_default=sa.text("'{}'"),
        ),
    )

    # Backfill existing users with raw phone digits, lowercased email and car_number digits.
    if dialect == "postgresql":
        op.execute(
            """
            UPDATE users
            SET "searchData" = jsonb_build_object(
                'phone', regexp_replace(coalesce(phone, ''), '\\D', '', 'g'),
                'email', lower(coalesce(email, '')),
                'car_number', regexp_replace(coalesce("carNumber", ''), '\\D', '', 'g')
            )
            """
        )
    else:
        _backfill_search_data(conn)

    if dialect == "postgresql":
        op.alter_column(
            "users",
            "searchData",
            nullable=False,
            server_default=sa.text("'{}'"),
        )
    else:
        with op.batch_alter_table("users") as batch_op:
            batch_op.alter_column(
                "searchData",
                existing_type=sa.JSON(),
                nullable=False,
            )


def downgrade() -> None:
    if _column_exists("users", "searchData"):
        _drop_column("users", "searchData")
