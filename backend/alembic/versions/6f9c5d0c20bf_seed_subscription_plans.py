"""seed subscription plans

Revision ID: 6f9c5d0c20bf
Revises: 233a498b70b6
Create Date: 2026-06-28 22:18:47.628233

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '6f9c5d0c20bf'
down_revision: Union[str, Sequence[str], None] = '233a498b70b6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Seed default subscription plans if the table is empty."""
    connection = op.get_bind()
    result = connection.execute(sa.text("SELECT COUNT(*) FROM subscription_plans"))
    if result.scalar() > 0:
        return

    plans_table = sa.table(
        "subscription_plans",
        sa.column("code", sa.String),
        sa.column("name", sa.String),
        sa.column("description", sa.String),
        sa.column("type", sa.String),
        sa.column("washCount", sa.Integer),
        sa.column("unlimitedDays", sa.Integer),
        sa.column("discountPercent", sa.Integer),
        sa.column("washTypePrices", sa.JSON),
        sa.column("sortOrder", sa.Integer),
        sa.column("isActive", sa.Boolean),
    )

    op.bulk_insert(
        plans_table,
        [
            {
                "code": "chistulya",
                "name": "Чистюля",
                "description": "5 моек со скидкой 10%",
                "type": "package",
                "washCount": 5,
                "unlimitedDays": None,
                "discountPercent": 10,
                "washTypePrices": None,
                "sortOrder": 1,
                "isActive": True,
            },
            {
                "code": "blesk-master",
                "name": "Блеск-мастер",
                "description": "10 моек со скидкой 15%",
                "type": "package",
                "washCount": 10,
                "unlimitedDays": None,
                "discountPercent": 15,
                "washTypePrices": None,
                "sortOrder": 2,
                "isActive": True,
            },
            {
                "code": "bezlimitka",
                "name": "Безлимитка",
                "description": "30 дней безлимитных моек одного типа",
                "type": "unlimited",
                "washCount": None,
                "unlimitedDays": 30,
                "discountPercent": 0,
                "washTypePrices": {"w1": 8000, "w2": 12000, "w3": 22000, "w4": 40000},
                "sortOrder": 3,
                "isActive": True,
            },
        ],
    )


def downgrade() -> None:
    """Remove seeded subscription plans."""
    op.execute(
        sa.text(
            "DELETE FROM subscription_plans WHERE code IN "
            "('chistulya', 'blesk-master', 'bezlimitka')"
        )
    )
