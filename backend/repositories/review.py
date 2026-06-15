from sqlalchemy.ext.asyncio import AsyncSession

from models import Review
from repositories.base import BaseRepository


class ReviewRepository(BaseRepository[Review]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Review)
