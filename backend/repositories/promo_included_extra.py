from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import PromoIncludedExtra
from repositories.base import BaseRepository


class PromoIncludedExtraRepository(BaseRepository[PromoIncludedExtra]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, PromoIncludedExtra)

    async def map_by_promo_ids(self, promo_ids: list[int]) -> dict[int, list[str]]:
        if not promo_ids:
            return {}
        result = await self._db.execute(
            select(PromoIncludedExtra.promoId, PromoIncludedExtra.extraServiceId)
            .where(PromoIncludedExtra.promoId.in_(promo_ids))
        )
        extras_map: dict[int, list[str]] = {}
        for promo_id, extra_id in result.all():
            extras_map.setdefault(promo_id, []).append(extra_id)
        return extras_map
