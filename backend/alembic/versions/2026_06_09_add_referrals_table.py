"""add referrals table

Revision ID: 2026_06_09_add_referrals_table
Revises: 2026_06_09_add_referral_code_to_users
Create Date: 2026-06-09 15:01:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = '2026_06_09_add_referrals_table'
down_revision: Union[str, Sequence[str], None] = '2026_06_09_add_referral_code_to_users'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'referrals',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('referrerId', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('referredId', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('rewardClaimed', sa.Boolean(), nullable=False, server_default='0'),
        sa.Column('createdAt', sa.String(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('referrerId', 'referredId', name='uq_referral_referrer_referred')
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('referrals')
