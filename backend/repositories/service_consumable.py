from sqlalchemy.ext.asyncio import AsyncSession

from models import ServiceConsumable
from repositories.base import BaseRepository


class ServiceConsumableRepository(BaseRepository[ServiceConsumable]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, ServiceConsumable)
