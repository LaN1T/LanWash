"""add_subscription_plans

Revision ID: 233a498b70b6
Revises: 42840ba4964a
Create Date: 2026-06-28 20:33:38.717637

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy import inspect

# revision identifiers, used by Alembic.
revision: str = '233a498b70b6'
down_revision: Union[str, None] = '42840ba4964a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _column_exists(table: str, column: str) -> bool:
    bind = op.get_bind()
    return column in {c["name"] for c in inspect(bind).get_columns(table)}


def _fk_exists(table: str, name: str) -> bool:
    bind = op.get_bind()
    return name in {fk["name"] for fk in inspect(bind).get_foreign_keys(table)}


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
    if not _column_exists('subscriptions', 'planId'):
        op.add_column('subscriptions', sa.Column('planId', sa.Integer(), nullable=True))
    if not _column_exists('subscriptions', 'price'):
        op.add_column('subscriptions', sa.Column('price', sa.Integer(), nullable=False, server_default='0'))
    if not _column_exists('subscriptions', 'originalPrice'):
        op.add_column('subscriptions', sa.Column('originalPrice', sa.Integer(), nullable=False, server_default='0'))
    if not _column_exists('subscriptions', 'selectedExtras'):
        op.add_column('subscriptions', sa.Column('selectedExtras', sa.String(), nullable=True))
    if not _column_exists('subscriptions', 'paymentStatus'):
        op.add_column('subscriptions', sa.Column('paymentStatus', sa.String(), nullable=False, server_default='pending'))
    if not _fk_exists('subscriptions', 'fk_subscriptions_plan_id'):
        with op.batch_alter_table('subscriptions', schema=None) as batch_op:
            batch_op.create_foreign_key(
                'fk_subscriptions_plan_id',
                'subscription_plans',
                ['planId'], ['id'], ondelete='SET NULL'
            )


def downgrade() -> None:
    if _fk_exists('subscriptions', 'fk_subscriptions_plan_id'):
        with op.batch_alter_table('subscriptions', schema=None) as batch_op:
            batch_op.drop_constraint('fk_subscriptions_plan_id', type_='foreignkey')
    if _column_exists('subscriptions', 'paymentStatus'):
        op.drop_column('subscriptions', 'paymentStatus')
    if _column_exists('subscriptions', 'selectedExtras'):
        op.drop_column('subscriptions', 'selectedExtras')
    if _column_exists('subscriptions', 'originalPrice'):
        op.drop_column('subscriptions', 'originalPrice')
    if _column_exists('subscriptions', 'price'):
        op.drop_column('subscriptions', 'price')
    if _column_exists('subscriptions', 'planId'):
        op.drop_column('subscriptions', 'planId')
    op.drop_table('subscription_plans')
