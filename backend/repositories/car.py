from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from models import Car
from repositories.base import BaseRepository


class CarRepository(BaseRepository[Car]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Car)

    async def list_for_user(self, user_id: int) -> list[Car]:
        result = await self._db.execute(
            select(Car).where(Car.userId == user_id).order_by(Car.id.asc())
        )
        return list(result.scalars().all())

    async def count_for_user(self, user_id: int) -> int:
        result = await self._db.execute(
            select(func.count(Car.id)).where(Car.userId == user_id)
        )
        return result.scalar() or 0

    async def get_with_lock(self, car_id: int) -> Car | None:
        result = await self._db.execute(
            select(Car).where(Car.id == car_id).with_for_update()
        )
        return result.scalar_one_or_none()

    async def set_non_primary_for_user(
        self, user_id: int, exclude_id: int | None = None
    ) -> None:
        stmt = (
            update(Car)
            .where(Car.userId == user_id, Car.isPrimary.is_(True))
            .values(isPrimary=False)
            .execution_options(synchronize_session="fetch")
        )
        if exclude_id is not None:
            stmt = stmt.where(Car.id != exclude_id)
        await self._db.execute(stmt)

    async def get_oldest_for_user(
        self, user_id: int, exclude_id: int | None = None
    ) -> Car | None:
        stmt = select(Car).where(Car.userId == user_id).order_by(Car.id.asc()).limit(1)
        if exclude_id is not None:
            stmt = stmt.where(Car.id != exclude_id)
        result = await self._db.execute(stmt)
        return result.scalar_one_or_none()
