"""add_unique_constraint_tip_appointment_washer

Revision ID: 74b101bd9fe2
Revises: 2026_06_09_add_tips_table
Create Date: 2026-06-09 18:19:31.010326

"""
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = '74b101bd9fe2'
down_revision: Union[str, Sequence[str], None] = '2026_06_09_add_tips_table'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_unique_constraint('uq_tip_appointment_washer', 'tips', ['appointmentId', 'washerUsername'])


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint('uq_tip_appointment_washer', 'tips', type_='unique')
