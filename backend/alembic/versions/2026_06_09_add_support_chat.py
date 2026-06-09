"""add support chat tables

Revision ID: a5112b68dcdf
Revises: d202fda86474
Create Date: 2026-06-09 21:55:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "a5112b68dcdf"
down_revision: Union[str, Sequence[str], None] = "d202fda86474"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "support_chats",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("userId", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("assignedAdminId", sa.Integer(), nullable=True),
        sa.Column("unreadByUser", sa.Integer(), nullable=False),
        sa.Column("unreadByAdmin", sa.Integer(), nullable=False),
        sa.Column("lastMessageAt", sa.String(), nullable=True),
        sa.Column("createdAt", sa.String(), nullable=False),
        sa.Column("updatedAt", sa.String(), nullable=False),
        sa.ForeignKeyConstraint(["assignedAdminId"], ["users.id"]),
        sa.ForeignKeyConstraint(["userId"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "support_messages",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("chatId", sa.Integer(), nullable=False),
        sa.Column("senderRole", sa.String(), nullable=False),
        sa.Column("senderId", sa.Integer(), nullable=True),
        sa.Column("content", sa.String(), nullable=False),
        sa.Column("isAiDraft", sa.Integer(), nullable=False),
        sa.Column("createdAt", sa.String(), nullable=False),
        sa.ForeignKeyConstraint(["chatId"], ["support_chats.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["senderId"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )


def downgrade() -> None:
    op.drop_table("support_messages")
    op.drop_table("support_chats")
