from sqlalchemy.ext.asyncio import AsyncSession

from models import Consumable
from repositories.base import BaseRepository


class ConsumableRepository(BaseRepository[Consumable]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Consumable)
