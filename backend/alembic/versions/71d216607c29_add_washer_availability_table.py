"""add washer availability table

Revision ID: 71d216607c29
Revises: 9e5de8425124
Create Date: 2026-06-15 13:50:23.976073

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '71d216607c29'
down_revision: Union[str, Sequence[str], None] = '9e5de8425124'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'washer_availability',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('userId', sa.Integer(), nullable=False),
        sa.Column('date', sa.String(), nullable=False),
        sa.Column('status', sa.String(), nullable=False),
        sa.Column('updatedAt', sa.String(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('userId', 'date', name='uq_washer_availability_user_date'),
        sa.ForeignKeyConstraint(['userId'], ['users.id'], ondelete='CASCADE'),
    )
    op.create_index('ix_washer_availability_user_date', 'washer_availability', ['userId', 'date'], unique=False)
    op.create_index('ix_washer_availability_date', 'washer_availability', ['date'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_washer_availability_date', table_name='washer_availability')
    op.drop_index('ix_washer_availability_user_date', table_name='washer_availability')
    op.drop_table('washer_availability')
