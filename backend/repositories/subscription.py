from sqlalchemy.ext.asyncio import AsyncSession

from models import Subscription
from repositories.base import BaseRepository


class SubscriptionRepository(BaseRepository[Subscription]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Subscription)
