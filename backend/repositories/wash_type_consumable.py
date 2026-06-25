from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import WashTypeConsumable
from repositories.base import BaseRepository


class WashTypeConsumableRepository(BaseRepository[WashTypeConsumable]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, WashTypeConsumable)

    async def list_by_wash_type(
        self, wash_type_id: str
    ) -> list[WashTypeConsumable]:
        result = await self._db.execute(
            select(WashTypeConsumable)
            .where(WashTypeConsumable.washTypeId == wash_type_id)
            .order_by(WashTypeConsumable.consumableId.asc())
        )
        return list(result.scalars().all())

    async def get_by_wash_type_and_consumable(
        self, wash_type_id: str, consumable_id: str
    ) -> WashTypeConsumable | None:
        result = await self._db.execute(
            select(WashTypeConsumable).where(
                WashTypeConsumable.washTypeId == wash_type_id,
                WashTypeConsumable.consumableId == consumable_id,
            )
        )
        return result.scalar_one_or_none()

    async def delete_by_consumable_id(self, consumable_id: str) -> int:
        result = await self._db.execute(
            delete(WashTypeConsumable).where(
                WashTypeConsumable.consumableId == consumable_id
            )
        )
        return result.rowcount

    async def delete_by_wash_type_and_consumable(
        self, wash_type_id: str, consumable_id: str
    ) -> bool:
        result = await self._db.execute(
            delete(WashTypeConsumable).where(
                WashTypeConsumable.washTypeId == wash_type_id,
                WashTypeConsumable.consumableId == consumable_id,
            )
        )
        return result.rowcount > 0

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
        result = await self._db.execute(
            select(WashTypeConsumable.consumableId).distinct()
        )
        return [row[0] for row in result.all()]

    async def list_all(self) -> list[WashTypeConsumable]:
        result = await self._db.execute(
            select(WashTypeConsumable).order_by(WashTypeConsumable.washTypeId.asc())
        )
        return list(result.scalars().all())

    async def list_all_wash_type_consumable_pairs(self) -> list[tuple[str, str]]:
        result = await self._db.execute(
            select(WashTypeConsumable.washTypeId, WashTypeConsumable.consumableId)
        )
        return list(result.all())
