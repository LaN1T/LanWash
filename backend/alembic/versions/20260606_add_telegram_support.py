"""add telegram support

Revision ID: 20260606_add_telegram
Revises: ff5315481019
Create Date: 2026-06-06 00:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260606_add_telegram"
down_revision: Union[str, Sequence[str], None] = "ff5315481019"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("users", sa.Column("telegramId", sa.String(), nullable=True))
    op.create_index("ix_users_telegramId", "users", ["telegramId"], unique=True)
    op.create_table(
        "notification_queue",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("telegramId", sa.String(), nullable=False),
        sa.Column("message", sa.String(), nullable=False),
        sa.Column("createdAt", sa.String(), nullable=False),
        sa.Column("sentAt", sa.String(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_notification_queue_sentAt", "notification_queue", ["sentAt"])


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_notification_queue_sentAt", table_name="notification_queue")
    op.drop_table("notification_queue")
    op.drop_index("ix_users_telegramId", table_name="users")
    op.drop_column("users", "telegramId")
