"""merge heads

Revision ID: d202fda86474
Revises: 2026_06_09_add_referrals_table, 2026_06_09_add_subscriptions_table
Create Date: 2026-06-10 00:55:07.545492

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd202fda86474'
down_revision: Union[str, Sequence[str], None] = ('2026_06_09_add_referrals_table', '2026_06_09_add_subscriptions_table')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
