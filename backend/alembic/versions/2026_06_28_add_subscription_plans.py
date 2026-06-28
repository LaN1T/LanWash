"""add_subscription_plans

Revision ID: 233a498b70b6
Revises: 42840ba4964a
Create Date: 2026-06-28 20:33:38.717637

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = '233a498b70b6'
down_revision: Union[str, None] = '42840ba4964a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'subscription_plans',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('code', sa.String(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('description', sa.String(), nullable=True),
        sa.Column('type', sa.String(), nullable=False),
        sa.Column('washCount', sa.Integer(), nullable=True),
        sa.Column('unlimitedDays', sa.Integer(), nullable=True),
        sa.Column('discountPercent', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('washTypePrices', sa.JSON(), nullable=True),
        sa.Column('sortOrder', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('isActive', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('createdAt', sa.DateTime(), nullable=False, server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('updatedAt', sa.DateTime(), nullable=False, server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('code'),
    )
    op.add_column('subscriptions', sa.Column('planId', sa.Integer(), nullable=True))
    op.add_column('subscriptions', sa.Column('price', sa.Integer(), nullable=False, server_default='0'))
    op.add_column('subscriptions', sa.Column('originalPrice', sa.Integer(), nullable=False, server_default='0'))
    op.add_column('subscriptions', sa.Column('selectedExtras', sa.String(), nullable=True))
    op.add_column('subscriptions', sa.Column('paymentStatus', sa.String(), nullable=False, server_default='pending'))
    with op.batch_alter_table('subscriptions', schema=None) as batch_op:
        batch_op.create_foreign_key(
            'fk_subscriptions_plan_id',
            'subscription_plans',
            ['planId'], ['id'], ondelete='SET NULL'
        )


def downgrade() -> None:
    with op.batch_alter_table('subscriptions', schema=None) as batch_op:
        batch_op.drop_constraint('fk_subscriptions_plan_id', type_='foreignkey')
    op.drop_column('subscriptions', 'paymentStatus')
    op.drop_column('subscriptions', 'selectedExtras')
    op.drop_column('subscriptions', 'originalPrice')
    op.drop_column('subscriptions', 'price')
    op.drop_column('subscriptions', 'planId')
    op.drop_table('subscription_plans')
