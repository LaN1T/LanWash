"""add_unique_constraint_review_user_appointment

Revision ID: 858f7591ce65
Revises: 2026_06_09_add_appointment_id_to_reviews
Create Date: 2026-06-09 17:01:25.670969

"""
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = '858f7591ce65'
down_revision: Union[str, Sequence[str], None] = '2026_06_09_add_appointment_id_to_reviews'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    with op.batch_alter_table('reviews', schema=None) as batch_op:
        batch_op.create_unique_constraint('uq_review_user_appointment', ['userId', 'appointmentId'])


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table('reviews', schema=None) as batch_op:
        batch_op.drop_constraint('uq_review_user_appointment', type_='unique')
