from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Review
from repositories.base import BaseRepository


class ReviewRepository(BaseRepository[Review]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Review)

    async def list_published_or_all(self, published_only: bool, limit: int) -> list[Review]:
        stmt = select(Review)
        if published_only:
            stmt = stmt.where(Review.isPublished == 1)
        stmt = stmt.order_by(Review.createdAt.desc()).limit(limit)
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def list_by_user(self, user_id: int, limit: int) -> list[Review]:
        result = await self._db.execute(
            select(Review)
            .where(Review.userId == user_id)
            .order_by(Review.createdAt.desc())
            .limit(limit)
        )
        return list(result.scalars().all())

    async def list_all(self, limit: int) -> list[Review]:
        result = await self._db.execute(
            select(Review).order_by(Review.createdAt.desc()).limit(limit)
        )
        return list(result.scalars().all())

    async def exists_for_user_appointment(self, user_id: int, appointment_id: str) -> bool:
        result = await self._db.execute(
            select(Review).where(
                Review.userId == user_id,
                Review.appointmentId == appointment_id,
            )
        )
        return result.scalar_one_or_none() is not None
