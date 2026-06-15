from sqlalchemy.ext.asyncio import AsyncSession

from models import WashTypeIncludedExtra
from repositories.base import BaseRepository


class WashTypeIncludedExtraRepository(BaseRepository[WashTypeIncludedExtra]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, WashTypeIncludedExtra)
