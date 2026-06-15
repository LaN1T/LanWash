from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Promo
from repositories.base import BaseRepository


class PromoRepository(BaseRepository[Promo]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Promo)

    async def list_all(self) -> list[Promo]:
        result = await self._db.execute(select(Promo))
        return list(result.scalars().all())
