from sqlalchemy.ext.asyncio import AsyncSession

from models import WasherAvailability
from repositories.base import BaseRepository


class WasherAvailabilityRepository(BaseRepository[WasherAvailability]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, WasherAvailability)
