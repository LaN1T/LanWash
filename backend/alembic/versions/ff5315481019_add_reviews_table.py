"""add reviews table

Revision ID: ff5315481019
Revises: c1f6857490b2
Create Date: 2026-06-02 00:41:03.567746

"""
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'ff5315481019'
down_revision: Union[str, Sequence[str], None] = 'c1f6857490b2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'reviews',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('userId', sa.Integer(), nullable=False),
        sa.Column('userName', sa.String(), nullable=False),
        sa.Column('rating', sa.Integer(), nullable=False, server_default='5'),
        sa.Column('comment', sa.String(), nullable=False, server_default=''),
        sa.Column('isPublished', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('createdAt', sa.String(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_reviews_isPublished', 'reviews', ['isPublished'])
    op.create_index('ix_reviews_userId', 'reviews', ['userId'])


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_reviews_userId', table_name='reviews')
    op.drop_index('ix_reviews_isPublished', table_name='reviews')
    op.drop_table('reviews')
