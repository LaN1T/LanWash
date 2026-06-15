from sqlalchemy.ext.asyncio import AsyncSession

from models import ConsumableRefillLog
from repositories.base import BaseRepository


class ConsumableRefillLogRepository(BaseRepository[ConsumableRefillLog]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, ConsumableRefillLog)
