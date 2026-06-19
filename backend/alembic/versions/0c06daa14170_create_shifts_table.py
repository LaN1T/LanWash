"""create shifts table

Revision ID: 0c06daa14170
Revises: 71d216607c29
Create Date: 2026-06-19 16:20:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "0c06daa14170"
down_revision: Union[str, Sequence[str], None] = "71d216607c29"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "shifts",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("userId", sa.Integer(), nullable=False),
        sa.Column("date", sa.String(), nullable=False),
        sa.Column("startTime", sa.String(), nullable=False),
        sa.Column("endTime", sa.String(), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="confirmed"),
        sa.Column("createdBy", sa.String(), nullable=False),
        sa.Column("createdAt", sa.String(), nullable=False),
        sa.Column("updatedAt", sa.String(), nullable=False),
        sa.ForeignKeyConstraint(["userId"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_shifts_user_date", "shifts", ["userId", "date"], unique=False)
    op.create_index(
        "ix_shifts_date_status", "shifts", ["date", "status"], unique=False
    )


def downgrade() -> None:
    op.drop_index("ix_shifts_date_status", table_name="shifts")
    op.drop_index("ix_shifts_user_date", table_name="shifts")
    op.drop_table("shifts")
