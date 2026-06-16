from sqlalchemy import and_, delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Shift, User
from repositories.base import BaseRepository


class ShiftRepository(BaseRepository[Shift]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Shift)

    async def list_for_range(
        self, start_date: str, end_date: str, user_id: int | None = None
    ) -> list[Shift]:
        stmt = select(Shift).where(
            and_(Shift.date >= start_date, Shift.date <= end_date)
        )
        if user_id is not None:
            stmt = stmt.where(Shift.userId == user_id)
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def list_today(
        self, today: str, status: str = "confirmed", user_id: int | None = None
    ) -> list[Shift]:
        stmt = (
            select(Shift)
            .where(and_(Shift.date == today, Shift.status == status))
            .order_by(Shift.startTime.asc())
        )
        if user_id is not None:
            stmt = stmt.where(Shift.userId == user_id)
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def list_current(
        self, today: str, status: str = "confirmed", user_id: int | None = None
    ) -> list[tuple[Shift, User]]:
        stmt = (
            select(Shift, User)
            .join(User, Shift.userId == User.id)
            .where(and_(Shift.date == today, Shift.status == status))
        )
        if user_id is not None:
            stmt = stmt.where(Shift.userId == user_id)
        result = await self._db.execute(stmt)
        return list(result.all())

    async def list_for_user(self, user_id: int, limit: int) -> list[Shift]:
        stmt = (
            select(Shift)
            .where(Shift.userId == user_id)
            .order_by(Shift.date.asc())
            .limit(limit)
        )
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def get_by_user_and_date(self, user_id: int, date: str) -> Shift | None:
        result = await self._db.execute(
            select(Shift).where(and_(Shift.userId == user_id, Shift.date == date))
        )
        return result.scalar_one_or_none()

    async def delete_for_user_and_date(self, user_id: int, date: str) -> int:
        result = await self._db.execute(
            delete(Shift).where(and_(Shift.userId == user_id, Shift.date == date))
        )
        return result.rowcount or 0
