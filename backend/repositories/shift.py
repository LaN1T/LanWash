from sqlalchemy.ext.asyncio import AsyncSession

from models import Shift
from repositories.base import BaseRepository


class ShiftRepository(BaseRepository[Shift]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Shift)
