from datetime import datetime

import structlog
from sqlalchemy.ext.asyncio import AsyncSession

from models import Subscription
from repositories.subscription import SubscriptionRepository
from repositories.user import UserRepository
from schemas import SubscriptionCreateRequest

logger = structlog.get_logger()


class SubscriptionNotFoundError(Exception):
    pass


class UserNotFoundError(Exception):
    pass


class SubscriptionsService:
    """Business logic for subscriptions."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._subscriptions = SubscriptionRepository(db)
        self._users = UserRepository(db)

    async def get_my_subscriptions(self, user_id: int) -> list[Subscription]:
        return await self._subscriptions.list_active_for_user(user_id)

    async def create_subscription(
        self, req: SubscriptionCreateRequest, admin_username: str
    ) -> Subscription:
        user = await self._users.get_by_id(req.userId)
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
            createdAt=datetime.now(),
        )
        await self._subscriptions.add(sub)
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
        sub = await self._subscriptions.get_active_for_user_with_lock(
            subscription_id, user_id
        )
        if not sub:
            raise SubscriptionNotFoundError()

        sub.usedWashes += 1
        await self._db.commit()
        await self._db.refresh(sub)
        return {"ok": True, "remaining": sub.totalWashes - sub.usedWashes}

    async def get_subscription_stats(self, user_id: int) -> dict:
        active_count = await self._subscriptions.count_active_for_user(user_id)
        total_saved = await self._subscriptions.sum_saved_for_user(user_id)
        return {"activeCount": active_count, "totalSaved": total_saved}
