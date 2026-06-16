from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import WashTypeConsumable
from repositories.base import BaseRepository


class WashTypeConsumableRepository(BaseRepository[WashTypeConsumable]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, WashTypeConsumable)

    async def list_for_wash_types(
        self, wash_type_ids: set[str] | list[str]
    ) -> list[WashTypeConsumable]:
        if not wash_type_ids:
            return []
        result = await self._db.execute(
            select(WashTypeConsumable).where(
                WashTypeConsumable.washTypeId.in_(wash_type_ids)
            )
        )
        return list(result.scalars().all())

    async def list_all_consumable_ids(self) -> list[str]:
        result = await self._db.execute(select(WashTypeConsumable.consumableId).distinct())
        return [row[0] for row in result.all()]
