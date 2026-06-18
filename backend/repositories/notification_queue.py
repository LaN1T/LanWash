from datetime import datetime

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from models import NotificationQueue
from repositories.base import BaseRepository


class NotificationQueueRepository(BaseRepository[NotificationQueue]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, NotificationQueue)

    async def add_notification(
        self,
        telegram_id: str,
        message: str,
    ) -> NotificationQueue:
        """Create a pending notification instance (not committed)."""
        notification = NotificationQueue(
            telegramId=telegram_id,
            message=message,
            createdAt=datetime.now().isoformat(),
            sentAt=None,
        )
        return await self.add(notification)

    async def get_pending(self, limit: int = 100) -> list[NotificationQueue]:
        """Return unsent notifications ordered by creation time."""
        result = await self._db.execute(
            select(self._model)
            .where(self._model.sentAt.is_(None))
            .order_by(self._model.createdAt.asc())
            .limit(limit)
        )
        return list(result.scalars().all())

    async def mark_sent_batch(self, notification_ids: list[int]) -> None:
        """Bulk-update sentAt for the given notification IDs (not committed)."""
        if not notification_ids:
            return
        await self._db.execute(
            update(self._model)
            .where(self._model.id.in_(notification_ids))
            .values(sentAt=datetime.now().isoformat())
        )
