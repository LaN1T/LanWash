import json
from datetime import date, datetime, timedelta

import structlog
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Subscription, SubscriptionPlan, WashType
from repositories.service import ServiceRepository
from repositories.subscription import SubscriptionRepository
from repositories.subscription_plan import SubscriptionPlanRepository
from repositories.user import UserRepository
from repositories.wash_type import WashTypeRepository
from schemas import (
    BuyPersonalSubscriptionRequest,
    BuyReadySubscriptionRequest,
    BuySubscriptionRequest,
    SubscriptionCreateRequest,
    SubscriptionPlanCreateRequest,
    SubscriptionPlanUpdateRequest,
)

logger = structlog.get_logger()

UNLIMITED_WASHES = 999999


class SubscriptionNotFoundError(Exception):
    pass


class UserNotFoundError(Exception):
    pass


class PlanNotFoundError(Exception):
    pass


class PlanAlreadyExistsError(Exception):
    pass


class InvalidPlanConfigurationError(Exception):
    pass


class WashTypeNotFoundError(Exception):
    pass


class SubscriptionsService:
    """Business logic for subscriptions."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._subscriptions = SubscriptionRepository(db)
        self._users = UserRepository(db)
        self._plans = SubscriptionPlanRepository(db)
        self._wash_types = WashTypeRepository(db)
        self._services = ServiceRepository(db)

    async def get_my_subscriptions(self, user_id: int) -> list[Subscription]:
        return await self._subscriptions.list_active_for_user(user_id)

    async def list_active_plans(self) -> list[SubscriptionPlan]:
        plans = await self._plans.list_active()
        return plans

    async def list_all_plans(self) -> list[SubscriptionPlan]:
        result = await self._db.execute(
            select(SubscriptionPlan).order_by(SubscriptionPlan.sortOrder.asc())
        )
        return list(result.scalars().all())

    async def create_plan(self, req: SubscriptionPlanCreateRequest) -> SubscriptionPlan:
        existing = await self._plans.get_by_code(req.code)
        if existing:
            raise PlanAlreadyExistsError()

        plan = SubscriptionPlan(**req.model_dump())
        await self._plans.add(plan)
        await self._db.commit()
        await self._db.refresh(plan)
        return plan

    async def update_plan(
        self, plan_id: int, req: SubscriptionPlanUpdateRequest
    ) -> SubscriptionPlan:
        plan = await self._plans.get_by_id(plan_id)
        if not plan:
            raise PlanNotFoundError()

        for field, value in req.model_dump(exclude_unset=True).items():
            setattr(plan, field, value)

        if plan.type == "package":
            plan.unlimitedDays = None
            plan.washTypePrices = None
        elif plan.type == "unlimited":
            plan.washCount = None
            plan.discountPercent = 0

        await self._db.commit()
        await self._db.refresh(plan)
        return plan

    async def delete_plan(self, plan_id: int) -> None:
        plan = await self._plans.get_by_id(plan_id)
        if not plan:
            raise PlanNotFoundError()
        plan.isActive = False
        await self._db.commit()

    async def _calculate_ready_package_price(
        self, plan: SubscriptionPlan, wash_type: WashType
    ) -> tuple[int, int]:
        original = wash_type.basePrice * plan.washCount
        price = original * (100 - plan.discountPercent) // 100
        return original, price

    async def _calculate_ready_unlimited_price(
        self, plan: SubscriptionPlan, wash_type_id: str
    ) -> tuple[int, int]:
        price = (plan.washTypePrices or {}).get(wash_type_id)
        if price is None:
            raise InvalidPlanConfigurationError(
                "Цена для выбранного типа мойки не задана"
            )
        return price, price

    async def _calculate_personal_price(
        self, req: BuyPersonalSubscriptionRequest, wash_type: WashType
    ) -> tuple[int, int]:
        selected_extras = json.loads(req.selectedExtras or "[]")
        prices = await self._services.get_prices(selected_extras)
        unknown_extras = [eid for eid in selected_extras if eid not in prices]
        if unknown_extras:
            raise InvalidPlanConfigurationError(
                "Указана неизвестная дополнительная услуга"
            )
        extras_total = sum(prices[eid] for eid in selected_extras)
        single = wash_type.basePrice + extras_total
        original = single * req.washCount

        if req.washCount >= 20:
            discount = 15
        elif req.washCount >= 10:
            discount = 10
        elif req.washCount >= 5:
            discount = 5
        else:
            discount = 0

        price = original * (100 - discount) // 100
        return original, price

    async def buy_subscription(
        self, req: BuySubscriptionRequest, user_id: int
    ) -> Subscription:
        if req.kind == "ready" and req.ready:
            return await self._buy_ready(req.ready, user_id)
        if req.kind == "personal" and req.personal:
            return await self._buy_personal(req.personal, user_id)
        raise InvalidPlanConfigurationError("Некорректный запрос покупки")

    async def _buy_ready(
        self, req: BuyReadySubscriptionRequest, user_id: int
    ) -> Subscription:
        plan = await self._plans.get_by_id(req.planId)
        if not plan or not plan.isActive:
            raise PlanNotFoundError()

        wash_type = await self._wash_types.get_by_id(req.washTypeId)
        if not wash_type:
            raise WashTypeNotFoundError()

        if plan.type == "package":
            if not plan.washCount:
                raise InvalidPlanConfigurationError(
                    "У пакета не задано количество моек"
                )
            original_price, price = await self._calculate_ready_package_price(
                plan, wash_type
            )
            total_washes = plan.washCount
            valid_until = None
        elif plan.type == "unlimited":
            if not plan.unlimitedDays:
                raise InvalidPlanConfigurationError("У безлимита не задан срок")
            original_price, price = await self._calculate_ready_unlimited_price(
                plan, req.washTypeId
            )
            total_washes = UNLIMITED_WASHES
            valid_until = date.today() + timedelta(days=plan.unlimitedDays)
        else:
            raise InvalidPlanConfigurationError("Неизвестный тип плана")

        sub = Subscription(
            userId=user_id,
            name=plan.name,
            type="package" if plan.type == "package" else "monthly",
            washTypeId=req.washTypeId,
            totalWashes=total_washes,
            usedWashes=0,
            validUntil=valid_until,
            planId=plan.id,
            price=price,
            originalPrice=original_price,
            paymentStatus="demo_purchased",
            createdAt=datetime.now(),
        )
        await self._subscriptions.add(sub)
        await self._db.commit()
        await self._db.refresh(sub)
        return sub

    async def _buy_personal(
        self, req: BuyPersonalSubscriptionRequest, user_id: int
    ) -> Subscription:
        wash_type = await self._wash_types.get_by_id(req.washTypeId)
        if not wash_type:
            raise WashTypeNotFoundError()

        original_price, price = await self._calculate_personal_price(req, wash_type)

        sub = Subscription(
            userId=user_id,
            name=f"Персональный абонемент ({req.washCount} моек)",
            type="package",
            washTypeId=req.washTypeId,
            totalWashes=req.washCount,
            usedWashes=0,
            validUntil=None,
            planId=None,
            price=price,
            originalPrice=original_price,
            selectedExtras=req.selectedExtras,  # already JSON string from validator
            paymentStatus="demo_purchased",
            createdAt=datetime.now(),
        )
        await self._subscriptions.add(sub)
        await self._db.commit()
        await self._db.refresh(sub)
        return sub

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

    async def restore_wash(self, subscription_id: int | None, washes: int = 1) -> None:
        """Decrement usedWashes when an appointment that consumed a subscription
        is cancelled or deleted."""
        if not subscription_id or washes <= 0:
            return
        sub = await self._subscriptions.get_by_id(subscription_id)
        if sub:
            sub.usedWashes = max(0, sub.usedWashes - washes)
            await self._db.commit()

    async def get_subscription_stats(self, user_id: int) -> dict:
        active_count = await self._subscriptions.count_active_for_user(user_id)
        total_saved = await self._subscriptions.sum_saved_for_user(user_id)
        return {"activeCount": active_count, "totalSaved": total_saved}
