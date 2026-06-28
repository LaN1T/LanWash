from sqlalchemy import select

from models import SubscriptionPlan
from repositories.base import BaseRepository


class SubscriptionPlanRepository(BaseRepository[SubscriptionPlan]):
    async def list_active(self) -> list[SubscriptionPlan]:
        result = await self._db.execute(
            select(SubscriptionPlan)
            .where(SubscriptionPlan.isActive)
            .order_by(SubscriptionPlan.sortOrder.asc())
        )
        return list(result.scalars().all())

    async def get_by_code(self, code: str) -> SubscriptionPlan | None:
        result = await self._db.execute(
            select(SubscriptionPlan).where(SubscriptionPlan.code == code)
        )
        return result.scalar_one_or_none()
