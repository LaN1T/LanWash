from sqlalchemy.ext.asyncio import AsyncSession

from models import Service
from repositories.base import BaseRepository


class ServiceRepository(BaseRepository[Service]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Service)
