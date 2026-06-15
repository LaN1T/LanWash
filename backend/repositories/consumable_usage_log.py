from sqlalchemy.ext.asyncio import AsyncSession

from models import ConsumableUsageLog
from repositories.base import BaseRepository


class ConsumableUsageLogRepository(BaseRepository[ConsumableUsageLog]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, ConsumableUsageLog)
