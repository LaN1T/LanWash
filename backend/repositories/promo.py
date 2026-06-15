from sqlalchemy.ext.asyncio import AsyncSession

from models import Promo
from repositories.base import BaseRepository


class PromoRepository(BaseRepository[Promo]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Promo)
