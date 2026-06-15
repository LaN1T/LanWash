from sqlalchemy import and_, delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import WasherAvailability
from repositories.base import BaseRepository


class WasherAvailabilityRepository(BaseRepository[WasherAvailability]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, WasherAvailability)

    async def list_for_range(
        self, user_id: int, start_date: str, end_date: str
    ) -> list[WasherAvailability]:
        result = await self._db.execute(
            select(WasherAvailability)
            .where(
                and_(
                    WasherAvailability.userId == user_id,
                    WasherAvailability.date >= start_date,
                    WasherAvailability.date <= end_date,
                )
            )
            .order_by(WasherAvailability.date.asc())
        )
        return list(result.scalars().all())

    async def list_for_dates(self, user_id: int, dates: list[str]) -> dict[str, WasherAvailability]:
        if not dates:
            return {}
        result = await self._db.execute(
            select(WasherAvailability).where(
                and_(WasherAvailability.userId == user_id, WasherAvailability.date.in_(dates))
            )
        )
        return {row.date: row for row in result.scalars().all()}

    async def delete_for_range(self, user_id: int, start_date: str, end_date: str) -> int:
        result = await self._db.execute(
            delete(WasherAvailability).where(
                and_(
                    WasherAvailability.userId == user_id,
                    WasherAvailability.date >= start_date,
                    WasherAvailability.date <= end_date,
                )
            )
        )
        return result.rowcount or 0
