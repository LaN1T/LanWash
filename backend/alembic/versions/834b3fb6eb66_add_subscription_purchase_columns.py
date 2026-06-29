"""Add subscription purchase columns.

Revision ID: 834b3fb6eb66
Revises: 6f9c5d0c20bf
Create Date: 2026-06-28 20:05:00.000000
"""

from typing import Sequence, Union

import sqlalchemy as sa
from sqlalchemy import inspect

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "834b3fb6eb66"
down_revision: Union[str, None] = "6f9c5d0c20bf"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _column_exists(table: str, column: str) -> bool:
    bind = op.get_bind()
    return column in {c["name"] for c in inspect(bind).get_columns(table)}


def upgrade() -> None:
    if not _column_exists("subscriptions", "planId"):
        op.add_column(
            "subscriptions",
            sa.Column(
                "planId",
                sa.Integer(),
                sa.ForeignKey("subscription_plans.id", ondelete="SET NULL"),
                nullable=True,
            ),
        )
    if not _column_exists("subscriptions", "price"):
        op.add_column(
            "subscriptions",
            sa.Column("price", sa.Integer(), nullable=False, server_default="0"),
        )
    if not _column_exists("subscriptions", "originalPrice"):
        op.add_column(
            "subscriptions",
            sa.Column(
                "originalPrice", sa.Integer(), nullable=False, server_default="0"
            ),
        )
    if not _column_exists("subscriptions", "selectedExtras"):
        op.add_column(
            "subscriptions",
            sa.Column("selectedExtras", sa.String(), nullable=True),
        )
    if not _column_exists("subscriptions", "paymentStatus"):
        op.add_column(
            "subscriptions",
            sa.Column(
                "paymentStatus", sa.String(), nullable=False, server_default="pending"
            ),
        )


def _drop_column(table: str, column: str) -> None:
    if op.get_bind().dialect.name == "sqlite":
        with op.batch_alter_table(table) as batch_op:
            batch_op.drop_column(column)
    else:
        op.drop_column(table, column)


def downgrade() -> None:
    if _column_exists("subscriptions", "paymentStatus"):
        _drop_column("subscriptions", "paymentStatus")
    if _column_exists("subscriptions", "selectedExtras"):
        _drop_column("subscriptions", "selectedExtras")
    if _column_exists("subscriptions", "originalPrice"):
        _drop_column("subscriptions", "originalPrice")
    if _column_exists("subscriptions", "price"):
        _drop_column("subscriptions", "price")
    if _column_exists("subscriptions", "planId"):
        _drop_column("subscriptions", "planId")
