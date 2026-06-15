from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Consumable
from repositories.base import BaseRepository


class ConsumableRepository(BaseRepository[Consumable]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Consumable)

    async def list_all_ordered(self) -> list[Consumable]:
        result = await self._db.execute(
            select(Consumable).order_by(Consumable.name.asc())
        )
        return list(result.scalars().all())

    async def list_low_stock_alerts(self) -> list[Consumable]:
        result = await self._db.execute(
            select(Consumable)
            .where(Consumable.currentStock < Consumable.minStock)
            .order_by(Consumable.name.asc())
        )
        return list(result.scalars().all())
