"""add cars table and migrate existing user car data

Revision ID: 2026_06_09_add_cars_table
Revises: 858f7591ce65
Create Date: 2026-06-09 14:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = '2026_06_09_add_cars_table'
down_revision: Union[str, Sequence[str], None] = '858f7591ce65'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'cars',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('userId', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('brand', sa.String(), nullable=False, server_default=''),
        sa.Column('model', sa.String(), nullable=False, server_default=''),
        sa.Column('number', sa.String(), nullable=False, server_default=''),
        sa.Column('isPrimary', sa.Boolean(), nullable=False, server_default='0'),
        sa.PrimaryKeyConstraint('id')
    )

    # Migrate existing data: for each user with non-empty carModel/carNumber, create a Car row
    # Use a safe approach: split carModel on first space into brand/model, or use whole string as brand
    conn = op.get_bind()
    if conn.dialect.name == 'sqlite':
        # SQLite approach
        conn.execute(sa.text("""
            INSERT INTO cars (userId, brand, model, number, isPrimary)
            SELECT
                id,
                CASE
                    WHEN instr(carModel, ' ') > 0 THEN substr(carModel, 1, instr(carModel, ' ') - 1)
                    ELSE carModel
                END,
                CASE
                    WHEN instr(carModel, ' ') > 0 THEN substr(carModel, instr(carModel, ' ') + 1)
                    ELSE ''
                END,
                carNumber,
                1
            FROM users
            WHERE carModel != '' OR carNumber != ''
        """))
    else:
        # PostgreSQL/MySQL approach
        conn.execute(sa.text("""
            INSERT INTO cars (userId, brand, model, number, isPrimary)
            SELECT
                id,
                CASE
                    WHEN POSITION(' ' IN carModel) > 0 THEN SPLIT_PART(carModel, ' ', 1)
                    ELSE carModel
                END,
                CASE
                    WHEN POSITION(' ' IN carModel) > 0 THEN SUBSTRING(carModel FROM POSITION(' ' IN carModel) + 1)
                    ELSE ''
                END,
                carNumber,
                TRUE
            FROM users
            WHERE carModel != '' OR carNumber != ''
        """))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('cars')
