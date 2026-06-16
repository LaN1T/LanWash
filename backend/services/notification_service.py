from typing import List

from sqlalchemy.ext.asyncio import AsyncSession

from models import NotificationQueue
from repositories import NotificationQueueRepository


async def add_notification(
    db: AsyncSession,
    telegram_id: str,
    message: str,
) -> NotificationQueue:
    """Add a notification to the queue."""
    repo = NotificationQueueRepository(db)
    notification = await repo.add_notification(telegram_id, message)
    await db.commit()
    await db.refresh(notification)
    return notification


async def get_pending_notifications(
    db: AsyncSession,
    limit: int = 100,
) -> List[NotificationQueue]:
    """Get unsent notifications."""
    repo = NotificationQueueRepository(db)
    return await repo.get_pending(limit)


async def mark_sent(
    db: AsyncSession,
    notification_id: int,
) -> None:
    """Mark a notification as sent."""
    await mark_sent_batch(db, [notification_id])


async def mark_sent_batch(
    db: AsyncSession,
    notification_ids: List[int],
) -> None:
    """Mark multiple notifications as sent in a single UPDATE."""
    repo = NotificationQueueRepository(db)
    await repo.mark_sent_batch(notification_ids)
    await db.commit()
