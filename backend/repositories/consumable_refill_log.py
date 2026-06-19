from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import ConsumableRefillLog
from repositories.base import BaseRepository


class ConsumableRefillLogRepository(BaseRepository[ConsumableRefillLog]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, ConsumableRefillLog)

    async def list_by_consumable(self, consumable_id: str) -> list[ConsumableRefillLog]:
        result = await self._db.execute(
            select(ConsumableRefillLog)
            .where(ConsumableRefillLog.consumableId == consumable_id)
            .order_by(ConsumableRefillLog.timestamp.desc())
        )
        return list(result.scalars().all())

    async def list_by_date_range(
        self, date_from: datetime | None, date_to: datetime | None
    ) -> list[ConsumableRefillLog]:
        stmt = select(ConsumableRefillLog).order_by(
            ConsumableRefillLog.timestamp.desc()
        )
        if date_from:
            stmt = stmt.where(ConsumableRefillLog.timestamp >= date_from)
        if date_to:
            stmt = stmt.where(ConsumableRefillLog.timestamp <= date_to)
        result = await self._db.execute(stmt)
        return list(result.scalars().all())
