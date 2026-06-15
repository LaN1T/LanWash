"""add email to users

Revision ID: 2026_06_10_add_email_to_users
Revises: d202fda86474
Create Date: 2026-06-10 12:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "2026_06_10_add_email_to_users"
down_revision: Union[str, Sequence[str], None] = "a5112b68dcdf"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "users", sa.Column("email", sa.String(), nullable=True, server_default="")
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("users", "email")
