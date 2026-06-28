from models import SubscriptionPlan
from repositories.base import BaseRepository


class SubscriptionPlanRepository(BaseRepository[SubscriptionPlan]):
    async def list_active(self) -> list[SubscriptionPlan]:
        from sqlalchemy import select
        result = await self._db.execute(
            select(SubscriptionPlan)
            .where(SubscriptionPlan.isActive == True)
            .order_by(SubscriptionPlan.sortOrder.asc())
        )
        return list(result.scalars().all())

    async def get_by_id(self, plan_id: int) -> SubscriptionPlan | None:
        from sqlalchemy import select
        result = await self._db.execute(
            select(SubscriptionPlan).where(SubscriptionPlan.id == plan_id)
        )
        return result.scalar_one_or_none()

    async def get_by_code(self, code: str) -> SubscriptionPlan | None:
        from sqlalchemy import select
        result = await self._db.execute(
            select(SubscriptionPlan).where(SubscriptionPlan.code == code)
        )
        return result.scalar_one_or_none()
