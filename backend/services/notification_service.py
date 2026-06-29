from sqlalchemy.ext.asyncio import AsyncSession

from models import NotificationQueue
from repositories import NotificationQueueRepository


async def add_notification(
    db: AsyncSession,
    telegram_id: str,
    message: str,
) -> NotificationQueue:
    """Add a notification to the queue.

    The caller is responsible for committing the session.
    """
    repo = NotificationQueueRepository(db)
    notification = await repo.add_notification(telegram_id, message)
    # Do not commit here; callers control transaction boundaries.
    return notification


async def get_pending_notifications(
    db: AsyncSession,
    limit: int = 100,
) -> list[NotificationQueue]:
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
    notification_ids: list[int],
) -> None:
    """Mark multiple notifications as sent in a single UPDATE."""
    if not notification_ids:
        return
    repo = NotificationQueueRepository(db)
    await repo.mark_sent_batch(notification_ids)
    await db.commit()
