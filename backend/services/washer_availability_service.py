from datetime import datetime
from typing import List

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from models import WasherAvailability
from repositories.user import UserRepository
from repositories.washer_availability import WasherAvailabilityRepository
from schemas import WasherAvailabilityEntry


class WasherAvailabilityService:
    """Business logic for washer availability calendar."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._availability = WasherAvailabilityRepository(db)
        self._users = UserRepository(db)

    async def get_availability(
        self, user_id: int, start_date: str, end_date: str
    ) -> List[WasherAvailability]:
        return await self._availability.list_for_range(user_id, start_date, end_date)

    async def update_availability(
        self, user_id: int, entries: List[WasherAvailabilityEntry]
    ) -> List[WasherAvailability]:
        user = await self._users.get_by_id(user_id)
        if not user:
            raise HTTPException(status_code=404, detail="Пользователь не найден")

        # Последняя запись для даты побеждает.
        latest: dict[str, str] = {}
        for entry in entries:
            latest[entry.date] = entry.status

        dates = list(latest.keys())
        if not dates:
            return []

        existing = await self._availability.list_for_dates(user_id, dates)

        now = datetime.now().isoformat()
        for date_str, status in latest.items():
            row = existing.get(date_str)
            if row:
                row.status = status
                row.updatedAt = now
            else:
                await self._availability.add(
                    WasherAvailability(
                        userId=user_id,
                        date=date_str,
                        status=status,
                        updatedAt=now,
                    )
                )

        await self._db.commit()
        return await self._availability.list_for_range(user_id, min(dates), max(dates))

    async def delete_availability(
        self, user_id: int, start_date: str, end_date: str
    ) -> int:
        deleted = await self._availability.delete_for_range(
            user_id, start_date, end_date
        )
        await self._db.commit()
        return deleted
