from sqlalchemy.ext.asyncio import AsyncSession

from models import SupportMessage
from repositories.base import BaseRepository


class SupportMessageRepository(BaseRepository[SupportMessage]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, SupportMessage)
