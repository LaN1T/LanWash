"""add subscriptions table and subscription_id to appointments

Revision ID: 2026_06_09_add_subscriptions_table
Revises: 74b101bd9fe2
Create Date: 2026-06-09 15:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "2026_06_09_add_subscriptions_table"
down_revision: Union[str, Sequence[str], None] = "74b101bd9fe2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "subscriptions",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column(
            "userId",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("type", sa.String(), nullable=False),
        sa.Column(
            "washTypeId", sa.String(), sa.ForeignKey("wash_types.id"), nullable=False
        ),
        sa.Column("totalWashes", sa.Integer(), nullable=False),
        sa.Column("usedWashes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("validUntil", sa.String(), nullable=True),
        sa.Column("createdAt", sa.String(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )

    op.add_column(
        "appointments",
        sa.Column(
            "subscriptionId",
            sa.Integer(),
            sa.ForeignKey("subscriptions.id"),
            nullable=True,
        ),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("appointments", "subscriptionId")
    op.drop_table("subscriptions")
