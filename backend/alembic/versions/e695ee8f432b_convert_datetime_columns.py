"""convert datetime columns

Revision ID: e695ee8f432b
Revises: 29ed997a5e49
Create Date: 2026-06-19 16:19:04.046927

"""
from typing import Sequence, Union

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql, sqlite

from alembic import op

revision: str = "e695ee8f432b"
down_revision: Union[str, Sequence[str], None] = "29ed997a5e49"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_DATE_COLUMNS = {
    "appointments": [("date", sa.Date())],
    "subscriptions": [("validUntil", sa.Date())],
    "shifts": [("date", sa.Date())],
    "washer_availability": [("date", sa.Date())],
}

_DATETIME_COLUMNS = {
    "users": [("createdAt", sa.DateTime())],
    "subscriptions": [("createdAt", sa.DateTime())],
    "appointments": [("dateTime", sa.DateTime()), ("date", sa.Date())],
    "services": [("updatedAt", sa.DateTime())],
    "promos": [("fetchedAt", sa.DateTime())],
    "logs": [("timestamp", sa.DateTime())],
    "washer_notes": [("createdAt", sa.DateTime())],
    "deleted_notifications": [("createdAt", sa.DateTime())],
    "fcm_tokens": [("updatedAt", sa.DateTime())],
    "consumable_usage_log": [("timestamp", sa.DateTime())],
    "consumable_refill_log": [("timestamp", sa.DateTime())],
    "shifts": [("createdAt", sa.DateTime()), ("updatedAt", sa.DateTime())],
    "washer_availability": [("updatedAt", sa.DateTime())],
    "notification_queue": [("createdAt", sa.DateTime()), ("sentAt", sa.DateTime())],
    "reviews": [("createdAt", sa.DateTime())],
    "referrals": [("createdAt", sa.DateTime())],
    "tips": [("createdAt", sa.DateTime())],
    "support_chats": [
        ("lastMessageAt", sa.DateTime()),
        ("createdAt", sa.DateTime()),
        ("updatedAt", sa.DateTime()),
    ],
    "support_messages": [("createdAt", sa.DateTime())],
    "admin_audit_logs": [("created_at", sa.DateTime())],
}

_TIME_COLUMNS = {
    "shifts": [("startTime", sa.Time()), ("endTime", sa.Time())],
}


def _compile_type(new_type: sa.types.TypeEngine, dialect_name: str) -> str:
    if dialect_name == "postgresql":
        return new_type.compile(dialect=postgresql.dialect())
    if dialect_name == "sqlite":
        return new_type.compile(dialect=sqlite.dialect())
    return str(new_type)


def _alter(table: str, column: str, new_type: sa.types.TypeEngine) -> None:
    dialect = op.get_context().dialect.name

    if dialect == "postgresql":
        pg_type = _compile_type(new_type, "postgresql")
        op.alter_column(
            table,
            column,
            type_=new_type,
            postgresql_using=f'"{column}"::{pg_type}',
        )
    elif dialect == "sqlite":
        with op.batch_alter_table(table, recreate="auto") as batch_op:
            batch_op.alter_column(column, type_=new_type)
    else:
        op.alter_column(table, column, type_=new_type)


def upgrade() -> None:
    for table, columns in _DATETIME_COLUMNS.items():
        for column, new_type in columns:
            _alter(table, column, new_type)
    for table, columns in _DATE_COLUMNS.items():
        for column, new_type in columns:
            _alter(table, column, new_type)
    for table, columns in _TIME_COLUMNS.items():
        for column, new_type in columns:
            _alter(table, column, new_type)


def downgrade() -> None:
    for table, columns in _TIME_COLUMNS.items():
        for column, old_type in columns:
            _alter(table, column, sa.String())
    for table, columns in _DATE_COLUMNS.items():
        for column, old_type in columns:
            _alter(table, column, sa.String())
    for table, columns in _DATETIME_COLUMNS.items():
        for column, old_type in columns:
            _alter(table, column, sa.String())
