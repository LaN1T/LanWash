from sqlalchemy.ext.asyncio import AsyncSession

from models import Tip
from repositories.base import BaseRepository


class TipRepository(BaseRepository[Tip]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Tip)
