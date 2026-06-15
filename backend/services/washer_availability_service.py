from datetime import datetime
from typing import List

from fastapi import HTTPException
from sqlalchemy import and_, delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import User, WasherAvailability
from schemas import WasherAvailabilityEntry


class WasherAvailabilityService:
    """Business logic for washer availability calendar."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_availability(
        self, user_id: int, start_date: str, end_date: str
    ) -> List[WasherAvailability]:
        stmt = (
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
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def update_availability(
        self, user_id: int, entries: List[WasherAvailabilityEntry]
    ) -> List[WasherAvailability]:
        user = await self._db.get(User, user_id)
        if not user:
            raise HTTPException(status_code=404, detail="Пользователь не найден")

        # Последняя запись для даты побеждает.
        latest: dict[str, str] = {}
        for entry in entries:
            latest[entry.date] = entry.status

        dates = list(latest.keys())
        if not dates:
            return []

        stmt = select(WasherAvailability).where(
            and_(WasherAvailability.userId == user_id, WasherAvailability.date.in_(dates))
        )
        result = await self._db.execute(stmt)
        existing = {row.date: row for row in result.scalars().all()}

        now = datetime.now().isoformat()
        for date_str, status in latest.items():
            row = existing.get(date_str)
            if row:
                row.status = status
                row.updatedAt = now
            else:
                self._db.add(
                    WasherAvailability(
                        userId=user_id,
                        date=date_str,
                        status=status,
                        updatedAt=now,
                    )
                )

        await self._db.commit()
        return await self.get_availability(user_id, min(dates), max(dates))

    async def delete_availability(
        self, user_id: int, start_date: str, end_date: str
    ) -> int:
        result = await self._db.execute(
            delete(WasherAvailability).where(
                and_(
                    WasherAvailability.userId == user_id,
                    WasherAvailability.date >= start_date,
                    WasherAvailability.date <= end_date,
                )
            )
        )
        await self._db.commit()
        return result.rowcount or 0
