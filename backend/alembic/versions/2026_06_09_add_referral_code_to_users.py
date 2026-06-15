"""add referral_code to users

Revision ID: 2026_06_09_add_referral_code_to_users
Revises: 2026_06_09_add_car_primary_unique_constraint
Create Date: 2026-06-09 15:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "2026_06_09_add_referral_code_to_users"
down_revision: Union[str, Sequence[str], None] = (
    "2026_06_09_add_car_primary_unique_constraint"
)
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column("users", sa.Column("referralCode", sa.String(), nullable=True))
    op.create_index("ix_users_referralCode", "users", ["referralCode"], unique=False)
    op.create_unique_constraint("uq_users_referral_code", "users", ["referralCode"])


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint("uq_users_referral_code", "users", type_="unique")
    op.drop_index("ix_users_referralCode", table_name="users")
    op.drop_column("users", "referralCode")
