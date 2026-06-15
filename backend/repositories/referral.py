from sqlalchemy.ext.asyncio import AsyncSession

from models import Referral
from repositories.base import BaseRepository


class ReferralRepository(BaseRepository[Referral]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Referral)
