from sqlalchemy.ext.asyncio import AsyncSession

from models import FcmToken
from repositories.base import BaseRepository


class FcmTokenRepository(BaseRepository[FcmToken]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, FcmToken)
