"""convert datetime columns

Revision ID: e695ee8f432b
Revises: 29ed997a5e49
Create Date: 2026-06-19 16:19:04.046927

"""
from typing import Sequence, Union

import sqlalchemy as sa

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


def _alter(table: str, column: str, new_type: sa.types.TypeEngine) -> None:
    using = f"{column}::{new_type}"
    op.execute(
        f'ALTER TABLE "{table}" ALTER COLUMN "{column}" TYPE {new_type} USING {using}'
    )


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
