"""add car number digits

Revision ID: b79c00c7d18d
Revises: 2026_06_28_add_user_search_data
Create Date: 2026-06-29 01:50:38.724417

"""
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op
from sqlalchemy import inspect

# revision identifiers, used by Alembic.
revision: str = "b79c00c7d18d"
down_revision: Union[str, Sequence[str], None] = "2026_06_28_add_user_search_data"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _digits(value: str | None) -> str:
    """Return only digits from a string."""
    return "".join(ch for ch in (value or "") if ch.isdigit())


def _column_exists(table: str, column: str) -> bool:
    bind = op.get_bind()
    return column in {c["name"] for c in inspect(bind).get_columns(table)}


def _index_exists(table: str, index: str) -> bool:
    bind = op.get_bind()
    return index in {i["name"] for i in inspect(bind).get_indexes(table)}


def _backfill_number_digits(conn: sa.Connection) -> None:
    """Fill numberDigits with digits extracted from number (SQLite/other)."""
    cars = sa.table(
        "cars",
        sa.column("id", sa.Integer),
        sa.column("number", sa.String),
        sa.column("numberDigits", sa.String),
    )

    rows = conn.execute(sa.select(cars.c.id, cars.c.number))
    for row in rows:
        conn.execute(
            sa.update(cars)
            .where(cars.c.id == row.id)
            .values(numberDigits=_digits(row.number))
        )


def upgrade() -> None:
    """Upgrade schema."""
    if not _column_exists("cars", "numberDigits"):
        op.add_column(
            "cars",
            sa.Column("numberDigits", sa.String(), nullable=True),
        )

        conn = op.get_bind()
        if conn.dialect.name == "postgresql":
            op.execute(
                """
                UPDATE cars
                SET "numberDigits" = regexp_replace(coalesce("number", ''), '\\D', '', 'g')
                """
            )
        else:
            _backfill_number_digits(conn)

    if not _index_exists("cars", "ix_cars_number_digits"):
        op.create_index(
            "ix_cars_number_digits",
            "cars",
            ["numberDigits"],
        )


def _drop_column(table: str, column: str) -> None:
    if op.get_bind().dialect.name == "sqlite":
        with op.batch_alter_table(table) as batch_op:
            batch_op.drop_column(column)
    else:
        op.drop_column(table, column)


def downgrade() -> None:
    """Downgrade schema."""
    if _index_exists("cars", "ix_cars_number_digits"):
        op.drop_index("ix_cars_number_digits", table_name="cars")
    if _column_exists("cars", "numberDigits"):
        _drop_column("cars", "numberDigits")
