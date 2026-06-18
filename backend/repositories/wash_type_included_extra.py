from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import WashTypeIncludedExtra
from repositories.base import BaseRepository


class WashTypeIncludedExtraRepository(BaseRepository[WashTypeIncludedExtra]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, WashTypeIncludedExtra)

    async def list_extras_for_wash_types(
        self, wash_type_ids: list[str]
    ) -> dict[str, list[str]]:
        if not wash_type_ids:
            return {}
        result = await self._db.execute(
            select(
                WashTypeIncludedExtra.washTypeId,
                WashTypeIncludedExtra.extraServiceId,
            ).where(WashTypeIncludedExtra.washTypeId.in_(wash_type_ids))
        )
        extras_map: dict[str, list[str]] = {}
        for wt_id, extra_id in result.all():
            extras_map.setdefault(wt_id, []).append(extra_id)
        return extras_map

    async def list_extra_ids_for_wash_type(self, wash_type_id: str) -> list[str]:
        result = await self._db.execute(
            select(WashTypeIncludedExtra.extraServiceId).where(
                WashTypeIncludedExtra.washTypeId == wash_type_id
            )
        )
        return [r[0] for r in result.all()]

    async def delete_by_wash_type(self, wash_type_id: str) -> int:
        result = await self._db.execute(
            delete(WashTypeIncludedExtra).where(
                WashTypeIncludedExtra.washTypeId == wash_type_id
            )
        )
        return result.rowcount
