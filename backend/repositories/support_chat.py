from sqlalchemy.ext.asyncio import AsyncSession

from models import SupportChat
from repositories.base import BaseRepository


class SupportChatRepository(BaseRepository[SupportChat]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, SupportChat)
