from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from db_models import WashType, WashTypeIncludedExtra
from models import WashTypeRequest


class WashTypesService:
    """Business logic for wash type management."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_all(self) -> list[WashType]:
        result = await self._db.execute(
            select(WashType).order_by(WashType.sortOrder.asc())
        )
        return list(result.scalars().all())

    async def get_extras_map(self, wash_type_ids: list[str]) -> dict[str, list[str]]:
        if not wash_type_ids:
            return {}
        extras_res = await self._db.execute(
            select(WashTypeIncludedExtra.washTypeId, WashTypeIncludedExtra.extraServiceId)
            .where(WashTypeIncludedExtra.washTypeId.in_(wash_type_ids))
        )
        extras_map: dict[str, list[str]] = {}
        for wt_id, extra_id in extras_res.all():
            extras_map.setdefault(wt_id, []).append(extra_id)
        return extras_map

    async def get_one(self, wash_type_id: str) -> WashType | None:
        result = await self._db.execute(
            select(WashType).where(WashType.id == wash_type_id)
        )
        return result.scalar_one_or_none()

    async def get_included_extra_ids(self, wash_type_id: str) -> list[str]:
        res = await self._db.execute(
            select(WashTypeIncludedExtra.extraServiceId)
            .where(WashTypeIncludedExtra.washTypeId == wash_type_id)
        )
        return [r[0] for r in res.all()]

    async def update(self, wash_type_id: str, req: WashTypeRequest) -> WashType | None:
        result = await self._db.execute(
            select(WashType).where(WashType.id == wash_type_id)
        )
        wt = result.scalar_one_or_none()
        if not wt:
            return None

        wt.code = req.code
        wt.name = req.name
        wt.description = req.description
        wt.basePrice = req.basePrice
        wt.durationMinutes = req.durationMinutes
        wt.sortOrder = req.sortOrder

        await self._db.execute(
            delete(WashTypeIncludedExtra).where(
                WashTypeIncludedExtra.washTypeId == wash_type_id
            )
        )
        for extra_id in req.includedExtraIds:
            self._db.add(
                WashTypeIncludedExtra(
                    washTypeId=wash_type_id, extraServiceId=extra_id
                )
            )

        await self._db.commit()
        await self._db.refresh(wt)
        return wt
