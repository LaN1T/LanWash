from sqlalchemy.ext.asyncio import AsyncSession

from core.cache import cache
from models import WashType, WashTypeIncludedExtra
from repositories import WashTypeIncludedExtraRepository, WashTypeRepository
from schemas import WashTypeRequest


class WashTypesService:
    """Business logic for wash type management."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._wash_types = WashTypeRepository(db)
        self._included_extras = WashTypeIncludedExtraRepository(db)

    async def get_all(self) -> list[dict]:
        cache_key = "wash_types:all"
        cached = await cache.get(cache_key)
        if cached is not None:
            return cached

        wash_types = await self._wash_types.list_all_sorted()
        extras_map = await self._included_extras.list_extras_for_wash_types(
            [wt.id for wt in wash_types]
        )
        data = [
            {
                "id": wt.id,
                "code": wt.code,
                "name": wt.name,
                "description": wt.description,
                "basePrice": wt.basePrice,
                "durationMinutes": wt.durationMinutes,
                "sortOrder": wt.sortOrder,
                "includedExtraIds": extras_map.get(wt.id, []),
            }
            for wt in wash_types
        ]
        await cache.set(cache_key, data, ttl=600)
        return data

    async def get_one(self, wash_type_id: str) -> WashType | None:
        return await self._wash_types.get_by_id(wash_type_id)

    async def get_included_extra_ids(self, wash_type_id: str) -> list[str]:
        return await self._included_extras.list_extra_ids_for_wash_type(wash_type_id)

    async def _invalidate_cache(self) -> None:
        await cache.delete("wash_types:all")

    async def update(self, wash_type_id: str, req: WashTypeRequest) -> WashType | None:
        wt = await self._wash_types.get_by_id(wash_type_id)
        if not wt:
            return None

        wt.code = req.code
        wt.name = req.name
        wt.description = req.description
        wt.basePrice = req.basePrice
        wt.durationMinutes = req.durationMinutes
        wt.sortOrder = req.sortOrder

        await self._included_extras.delete_by_wash_type(wash_type_id)
        for extra_id in req.includedExtraIds:
            await self._included_extras.add(
                WashTypeIncludedExtra(washTypeId=wash_type_id, extraServiceId=extra_id)
            )

        await self._db.commit()
        await self._db.refresh(wt)
        await self._invalidate_cache()
        return wt
