from sqlalchemy.ext.asyncio import AsyncSession

from models import ExtraFavorite
from repositories.base import BaseRepository


class ExtraFavoriteRepository(BaseRepository[ExtraFavorite]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, ExtraFavorite)
