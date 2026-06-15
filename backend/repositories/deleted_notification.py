from sqlalchemy.ext.asyncio import AsyncSession

from models import DeletedNotification
from repositories.base import BaseRepository


class DeletedNotificationRepository(BaseRepository[DeletedNotification]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, DeletedNotification)
