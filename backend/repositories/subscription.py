from datetime import datetime
from decimal import Decimal

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Appointment, Subscription
from repositories.base import BaseRepository


class SubscriptionRepository(BaseRepository[Subscription]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Subscription)

    def _active_filters(self, user_id: int, today: str):
        return (
            Subscription.userId == user_id,
            Subscription.usedWashes < Subscription.totalWashes,
            or_(Subscription.validUntil.is_(None), Subscription.validUntil >= today),
        )

    async def list_active_for_user(self, user_id: int) -> list[Subscription]:
        today = datetime.now().isoformat()[:10]
        result = await self._db.execute(
            select(Subscription)
            .where(*self._active_filters(user_id, today))
            .order_by(Subscription.createdAt.desc())
        )
        return list(result.scalars().all())

    async def get_active_for_user_with_lock(self, subscription_id: int, user_id: int) -> Subscription | None:
        today = datetime.now().isoformat()[:10]
        result = await self._db.execute(
            select(Subscription)
            .where(
                Subscription.id == subscription_id,
                *self._active_filters(user_id, today),
            )
            .with_for_update()
        )
        return result.scalar_one_or_none()

    async def count_active_for_user(self, user_id: int) -> int:
        today = datetime.now().isoformat()[:10]
        result = await self._db.execute(
            select(func.count(Subscription.id)).where(*self._active_filters(user_id, today))
        )
        return result.scalar() or 0

    async def sum_saved_for_user(self, user_id: int) -> Decimal:
        result = await self._db.execute(
            select(func.coalesce(func.sum(Appointment.originalPrice), 0)).where(
                Appointment.userId == user_id,
                Appointment.subscriptionId.is_not(None),
            )
        )
        return result.scalar() or 0
