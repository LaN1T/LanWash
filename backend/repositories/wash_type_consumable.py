from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import WashTypeConsumable
from repositories.base import BaseRepository


class WashTypeConsumableRepository(BaseRepository[WashTypeConsumable]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, WashTypeConsumable)

    async def list_all_consumable_ids(self) -> list[str]:
        result = await self._db.execute(select(WashTypeConsumable.consumableId).distinct())
        return [row[0] for row in result.all()]
