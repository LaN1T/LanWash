"""add tips table

Revision ID: 2026_06_09_add_tips_table
Revises: ff5315481019_add_reviews_table
Create Date: 2026-06-09 15:10:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = '2026_06_09_add_tips_table'
down_revision: Union[str, Sequence[str], None] = 'ff5315481019'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'tips',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('appointmentId', sa.String(), sa.ForeignKey('appointments.id'), nullable=False),
        sa.Column('washerUsername', sa.String(), nullable=False),
        sa.Column('amount', sa.Integer(), nullable=False),
        sa.Column('method', sa.String(), nullable=False, server_default='sbp'),
        sa.Column('status', sa.String(), nullable=False, server_default='pending'),
        sa.Column('createdAt', sa.String(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('tips')
