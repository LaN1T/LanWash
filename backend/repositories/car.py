from sqlalchemy.ext.asyncio import AsyncSession

from models import Car
from repositories.base import BaseRepository


class CarRepository(BaseRepository[Car]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Car)
