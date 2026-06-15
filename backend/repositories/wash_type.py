from sqlalchemy.ext.asyncio import AsyncSession

from models import WashType
from repositories.base import BaseRepository


class WashTypeRepository(BaseRepository[WashType]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, WashType)
