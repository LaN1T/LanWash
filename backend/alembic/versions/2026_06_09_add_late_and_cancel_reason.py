"""add late_minutes and cancel_reason to appointments

Revision ID: 2026_06_09_add_late_and_cancel_reason
Revises: 20260606_add_telegram
Create Date: 2026-06-09 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = '2026_06_09_add_late_and_cancel_reason'
down_revision: Union[str, Sequence[str], None] = '20260606_add_telegram'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Use batch_alter_table for SQLite compatibility when adding columns with defaults
    with op.batch_alter_table('appointments', schema=None) as batch_op:
        batch_op.add_column(sa.Column('late_minutes', sa.Integer(), nullable=False, server_default='0'))
        batch_op.add_column(sa.Column('cancel_reason', sa.String(), nullable=False, server_default=''))


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table('appointments', schema=None) as batch_op:
        batch_op.drop_column('cancel_reason')
        batch_op.drop_column('late_minutes')
