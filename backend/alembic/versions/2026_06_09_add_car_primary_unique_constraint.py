"""add unique constraint on userId + isPrimary for cars

Revision ID: 2026_06_09_add_car_primary_unique_constraint
Revises: 2026_06_09_add_cars_table
Create Date: 2026-06-09 14:30:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "2026_06_09_add_car_primary_unique_constraint"
down_revision: Union[str, Sequence[str], None] = "2026_06_09_add_cars_table"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # First, ensure there is at most one primary car per user by clearing duplicates
    conn = op.get_bind()
    if conn.dialect.name == "sqlite":
        conn.execute(
            sa.text("""
            UPDATE cars
            SET isPrimary = 0
            WHERE id NOT IN (
                SELECT MIN(id)
                FROM cars
                WHERE isPrimary = 1
                GROUP BY userId
            )
            AND isPrimary = 1
        """)
        )
        op.create_index(
            "uq_user_primary_car",
            "cars",
            ["userId"],
            unique=True,
            sqlite_where=sa.text('"isPrimary" = 1'),
        )
    else:
        conn.execute(
            sa.text("""
            UPDATE cars
            SET isPrimary = FALSE
            WHERE id NOT IN (
                SELECT MIN(id)
                FROM cars
                WHERE isPrimary = TRUE
                GROUP BY userId
            )
            AND isPrimary = TRUE
        """)
        )
        op.create_index(
            "uq_user_primary_car",
            "cars",
            ["userId"],
            unique=True,
            postgresql_where=sa.text('"isPrimary" = TRUE'),
        )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("uq_user_primary_car", table_name="cars")
