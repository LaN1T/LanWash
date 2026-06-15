from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from models import User
from repositories.base import BaseRepository


class UserRepository(BaseRepository[User]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, User)

    async def get_by_username(self, username: str) -> User | None:
        result = await self._db.execute(
            select(User).where(User.username == username)
        )
        return result.scalar_one_or_none()

    async def get_by_telegram_id(self, telegram_id: str) -> User | None:
        result = await self._db.execute(
            select(User).where(User.telegramId == telegram_id)
        )
        return result.scalar_one_or_none()

    async def get_by_referral_code(self, code: str) -> User | None:
        result = await self._db.execute(
            select(User).where(User.referralCode == code)
        )
        return result.scalar_one_or_none()

    async def list_washers(self) -> list[User]:
        result = await self._db.execute(
            select(User)
            .where(User.role == "washer")
            .order_by(User.displayName.asc())
        )
        return list(result.scalars().all())

    async def update_fields(self, pk: int, updates: dict) -> int:
        result = await self._db.execute(
            update(User).where(User.id == pk).values(updates)
        )
        return result.rowcount or 0
