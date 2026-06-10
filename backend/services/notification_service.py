from datetime import datetime
from typing import List

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from db_models import NotificationQueue


async def add_notification(
    db: AsyncSession,
    telegram_id: str,
    message: str,
) -> NotificationQueue:
    """Add a notification to the queue."""
    notification = NotificationQueue(
        telegramId=telegram_id,
        message=message,
        createdAt=datetime.now().isoformat(),
        sentAt=None,
    )
    db.add(notification)
    await db.commit()
    await db.refresh(notification)
    return notification


async def get_pending_notifications(
    db: AsyncSession,
    limit: int = 100,
) -> List[NotificationQueue]:
    """Get unsent notifications."""
    result = await db.execute(
        select(NotificationQueue)
        .where(NotificationQueue.sentAt.is_(None))
        .order_by(NotificationQueue.createdAt.asc())
        .limit(limit)
    )
    return list(result.scalars().all())


async def mark_sent(
    db: AsyncSession,
    notification_id: int,
) -> None:
    """Mark a notification as sent."""
    await db.execute(
        update(NotificationQueue)
        .where(NotificationQueue.id == notification_id)
        .values(sentAt=datetime.now().isoformat())
    )
    await db.commit()
