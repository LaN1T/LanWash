"""add appointment_id to reviews

Revision ID: 2026_06_09_add_appointment_id_to_reviews
Revises: 2026_06_09_add_late_and_cancel_reason
Create Date: 2026-06-09 13:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "2026_06_09_add_appointment_id_to_reviews"
down_revision: Union[str, Sequence[str], None] = "2026_06_09_add_late_and_cancel_reason"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    with op.batch_alter_table("reviews", schema=None) as batch_op:
        batch_op.add_column(sa.Column("appointmentId", sa.String(), nullable=True))
        batch_op.create_index("ix_reviews_appointmentId", ["appointmentId"])
        batch_op.create_foreign_key(
            "fk_reviews_appointment_id", "appointments", ["appointmentId"], ["id"]
        )


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("reviews", schema=None) as batch_op:
        batch_op.drop_constraint("fk_reviews_appointment_id", type_="foreignkey")
        batch_op.drop_index("ix_reviews_appointmentId")
        batch_op.drop_column("appointmentId")
