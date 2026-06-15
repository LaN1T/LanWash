from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import FcmToken
from repositories.base import BaseRepository


class FcmTokenRepository(BaseRepository[FcmToken]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, FcmToken)

    async def get_by_username(self, username: str) -> FcmToken | None:
        result = await self._db.execute(
            select(FcmToken).where(FcmToken.username == username)
        )
        return result.scalar_one_or_none()
