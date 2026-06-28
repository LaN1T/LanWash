import structlog
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from core.limiter import limiter
from db.session import get_db
from models import SubscriptionPlan, User
from schemas import (
    BuySubscriptionRequest,
    SubscriptionCreateRequest,
    SubscriptionPlanCreateRequest,
    SubscriptionPlanResponse,
    SubscriptionPlanUpdateRequest,
    SubscriptionResponse,
    SubscriptionStatsResponse,
)
from services.auth_service import check_roles, get_current_user
from services.subscriptions_service import (
    InvalidPlanConfigurationError,
    PlanNotFoundError,
    SubscriptionNotFoundError,
    SubscriptionsService,
    UserNotFoundError,
    WashTypeNotFoundError,
)

logger = structlog.get_logger()

router = APIRouter(
    prefix="/api/subscriptions",
    tags=["subscriptions"],
)


@router.get("/my", response_model=list[SubscriptionResponse])
@limiter.limit("60/minute")
async def get_my_subscriptions(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Returns current user's active subscriptions."""
    svc = SubscriptionsService(db)
    return await svc.get_my_subscriptions(current_user.id)


@router.get("/plans", response_model=list[SubscriptionPlanResponse])
@limiter.limit("60/minute")
async def get_subscription_plans(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List active subscription plans for clients."""
    svc = SubscriptionsService(db)
    return await svc.list_active_plans()


@router.post("/buy", response_model=SubscriptionResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("10/minute")
async def buy_subscription(
    request: Request,
    req: BuySubscriptionRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Client buys a ready-made or personal subscription."""
    svc = SubscriptionsService(db)
    try:
        return await svc.buy_subscription(req, current_user.id)
    except PlanNotFoundError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "План не найден")
    except WashTypeNotFoundError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Тип мойки не найден")
    except InvalidPlanConfigurationError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc))


@router.post(
    "/", response_model=SubscriptionResponse, status_code=status.HTTP_201_CREATED
)
@limiter.limit("30/minute")
async def create_subscription(
    request: Request,
    req: SubscriptionCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    """Admin creates a subscription for a user."""
    svc = SubscriptionsService(db)
    try:
        return await svc.create_subscription(req, current_user.username)
    except UserNotFoundError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Пользователь не найден")


@router.post("/{subscription_id}/use")
@limiter.limit("60/minute")
async def use_subscription(
    request: Request,
    subscription_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Internal endpoint to decrement subscription usage.
    Called by appointment creation."""
    svc = SubscriptionsService(db)
    try:
        return await svc.use_subscription(subscription_id, current_user.id)
    except SubscriptionNotFoundError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Активный абонемент не найден")


@router.get("/stats", response_model=SubscriptionStatsResponse)
@limiter.limit("60/minute")
async def get_subscription_stats(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Returns subscription stats for the current user."""
    svc = SubscriptionsService(db)
    stats = await svc.get_subscription_stats(current_user.id)
    return SubscriptionStatsResponse(**stats)


@router.get(
    "/admin/plans",
    response_model=list[SubscriptionPlanResponse],
    dependencies=[Depends(check_roles(["admin"]))],
)
@limiter.limit("60/minute")
async def list_all_plans(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import select
    result = await db.execute(select(SubscriptionPlan).order_by(SubscriptionPlan.sortOrder.asc()))
    return list(result.scalars().all())


@router.post(
    "/admin/plans",
    response_model=SubscriptionPlanResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(check_roles(["admin"]))],
)
@limiter.limit("30/minute")
async def create_plan(
    request: Request,
    req: SubscriptionPlanCreateRequest,
    db: AsyncSession = Depends(get_db),
):
    plan = SubscriptionPlan(**req.model_dump())
    db.add(plan)
    await db.commit()
    await db.refresh(plan)
    return plan


@router.put(
    "/admin/plans/{plan_id}",
    response_model=SubscriptionPlanResponse,
    dependencies=[Depends(check_roles(["admin"]))],
)
@limiter.limit("30/minute")
async def update_plan(
    request: Request,
    plan_id: int,
    req: SubscriptionPlanUpdateRequest,
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import select
    result = await db.execute(select(SubscriptionPlan).where(SubscriptionPlan.id == plan_id))
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "План не найден")
    for field, value in req.model_dump(exclude_unset=True).items():
        setattr(plan, field, value)
    await db.commit()
    await db.refresh(plan)
    return plan


@router.delete(
    "/admin/plans/{plan_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(check_roles(["admin"]))],
)
@limiter.limit("30/minute")
async def delete_plan(
    request: Request,
    plan_id: int,
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import select
    result = await db.execute(select(SubscriptionPlan).where(SubscriptionPlan.id == plan_id))
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "План не найден")
    plan.isActive = False
    await db.commit()
    return None
