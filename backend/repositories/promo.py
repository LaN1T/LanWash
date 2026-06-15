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

    async def list_all_id_name_map(self) -> dict[str, str]:
        result = await self._db.execute(select(Promo.id, Promo.name))
        return {row[0]: row[1] for row in result.all()}

    async def get_durations(self, promo_ids: list[str]) -> dict[str, int]:
        if not promo_ids:
            return {}
        result = await self._db.execute(
            select(Promo.id, Promo.duration).where(Promo.id.in_(promo_ids))
        )
        return {row[0]: row[1] for row in result.all()}
