from sqlalchemy.ext.asyncio import AsyncSession

from models import NotificationQueue
from repositories.base import BaseRepository


class NotificationQueueRepository(BaseRepository[NotificationQueue]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, NotificationQueue)
