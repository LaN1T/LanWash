from sqlalchemy.ext.asyncio import AsyncSession

from models import PromoIncludedExtra
from repositories.base import BaseRepository


class PromoIncludedExtraRepository(BaseRepository[PromoIncludedExtra]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, PromoIncludedExtra)
