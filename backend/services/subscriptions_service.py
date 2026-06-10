from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_
from db_models import Subscription, User, Appointment
from models import SubscriptionCreateRequest
from datetime import datetime
import structlog

logger = structlog.get_logger()


class SubscriptionNotFoundError(Exception):
    pass


class UserNotFoundError(Exception):
    pass


class SubscriptionsService:
    """Business logic for subscriptions."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_my_subscriptions(self, user_id: int) -> list[Subscription]:
        today = datetime.now().isoformat()[:10]
        result = await self._db.execute(
            select(Subscription).where(
                Subscription.userId == user_id,
                Subscription.usedWashes < Subscription.totalWashes,
                or_(Subscription.validUntil == None, Subscription.validUntil >= today),
            ).order_by(Subscription.createdAt.desc())
        )
        return list(result.scalars().all())

    async def create_subscription(self, req: SubscriptionCreateRequest, admin_username: str) -> Subscription:
        user_res = await self._db.execute(select(User).where(User.id == req.userId))
        user = user_res.scalar_one_or_none()
        if not user:
            raise UserNotFoundError()

        sub = Subscription(
            userId=req.userId,
            name=req.name,
            type=req.type,
            washTypeId=req.washTypeId,
            totalWashes=req.totalWashes,
            usedWashes=0,
            validUntil=req.validUntil,
            createdAt=datetime.now().isoformat(),
        )
        self._db.add(sub)
        await self._db.commit()
        await self._db.refresh(sub)
        logger.info(
            "subscription_created",
            subscription_id=sub.id,
            user_id=req.userId,
            admin=admin_username,
        )
        return sub

    async def use_subscription(self, subscription_id: int, user_id: int) -> dict:
        today = datetime.now().isoformat()[:10]
        result = await self._db.execute(
            select(Subscription).where(
                Subscription.id == subscription_id,
                Subscription.userId == user_id,
                Subscription.usedWashes < Subscription.totalWashes,
                or_(Subscription.validUntil == None, Subscription.validUntil >= today),
            ).with_for_update()
        )
        sub = result.scalar_one_or_none()
        if not sub:
            raise SubscriptionNotFoundError()

        sub.usedWashes += 1
        await self._db.commit()
        await self._db.refresh(sub)
        return {"ok": True, "remaining": sub.totalWashes - sub.usedWashes}

    async def get_subscription_stats(self, user_id: int) -> dict:
        today = datetime.now().isoformat()[:10]
        active_res = await self._db.execute(
            select(func.count(Subscription.id)).where(
                Subscription.userId == user_id,
                Subscription.usedWashes < Subscription.totalWashes,
                or_(Subscription.validUntil == None, Subscription.validUntil >= today),
            )
        )
        active_count = active_res.scalar() or 0

        saved_res = await self._db.execute(
            select(func.coalesce(func.sum(Appointment.originalPrice), 0)).where(
                Appointment.userId == user_id,
                Appointment.subscriptionId != None,
            )
        )
        total_saved = saved_res.scalar() or 0

        return {"activeCount": active_count, "totalSaved": total_saved}
