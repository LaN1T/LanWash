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

    async def list_tokens_by_username(self, username: str) -> list[str]:
        result = await self._db.execute(
            select(FcmToken.token).where(FcmToken.username == username)
        )
        return [row[0] for row in result.all() if row[0]]
