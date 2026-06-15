from sqlalchemy.ext.asyncio import AsyncSession

from models import WashTypeConsumable
from repositories.base import BaseRepository


class WashTypeConsumableRepository(BaseRepository[WashTypeConsumable]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, WashTypeConsumable)
