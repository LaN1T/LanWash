"""add is_telegram_dummy flag to users

Revision ID: 963a155871fe
Revises: b79c00c7d18d
Create Date: 2026-06-29 13:32:18.599577

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '963a155871fe'
down_revision: Union[str, Sequence[str], None] = 'b79c00c7d18d'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _column_exists(table: str, column: str) -> bool:
    bind = op.get_bind()
    return column in {c["name"] for c in sa.inspect(bind).get_columns(table)}


def upgrade() -> None:
    """Upgrade schema."""
    if not _column_exists("users", "isTelegramDummy"):
        # Add the column nullable first, backfill, then enforce NOT NULL so the
        # operation works on both SQLite (which requires batch alter) and Postgres.
        op.add_column(
            "users",
            sa.Column("isTelegramDummy", sa.Boolean(), nullable=True),
        )

    bind = op.get_bind()
    users = sa.table(
        "users",
        sa.column("id", sa.Integer),
        sa.column("username", sa.String),
        sa.column("isTelegramDummy", sa.Boolean),
    )

    # Mark legacy auto-created tg_<id> accounts.
    op.execute(
        sa.update(users)
        .where(users.c.username.like("tg_%"))
        .where(users.c.isTelegramDummy.is_(None) | (users.c.isTelegramDummy == False))  # noqa: E712
        .values(isTelegramDummy=True)
    )

    # Ensure any remaining NULL rows are False.
    op.execute(
        sa.update(users)
        .where(users.c.isTelegramDummy.is_(None))
        .values(isTelegramDummy=False)
    )

    # SQLite requires batch_alter_table to change column nullability.
    if bind.dialect.name == "sqlite":
        with op.batch_alter_table("users") as batch_op:
            batch_op.alter_column(
                "isTelegramDummy",
                existing_type=sa.Boolean(),
                nullable=False,
            )
    else:
        op.alter_column(
            "users",
            "isTelegramDummy",
            existing_type=sa.Boolean(),
            nullable=False,
        )


def downgrade() -> None:
    """Downgrade schema."""
    if _column_exists("users", "isTelegramDummy"):
        op.drop_column("users", "isTelegramDummy")
