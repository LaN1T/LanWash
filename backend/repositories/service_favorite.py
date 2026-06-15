from sqlalchemy.ext.asyncio import AsyncSession

from models import ServiceFavorite
from repositories.base import BaseRepository


class ServiceFavoriteRepository(BaseRepository[ServiceFavorite]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, ServiceFavorite)
