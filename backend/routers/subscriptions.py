import uuid
from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, status, Response, Request
from core.limiter import limiter
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, func, or_, and_
from database import get_db
from models import SubscriptionCreateRequest, SubscriptionResponse, SubscriptionStatsResponse
from db_models import Subscription, User, Appointment
from services.auth_service import get_current_user, check_roles
import structlog

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
    today = datetime.now().isoformat()[:10]
    result = await db.execute(
        select(Subscription).where(
            Subscription.userId == current_user.id,
            Subscription.usedWashes < Subscription.totalWashes,
            or_(Subscription.validUntil == None, Subscription.validUntil >= today),
        ).order_by(Subscription.createdAt.desc())
    )
    return result.scalars().all()


@router.post("/", response_model=SubscriptionResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("30/minute")
async def create_subscription(
    request: Request,
    req: SubscriptionCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    """Admin creates a subscription for a user."""
    user_res = await db.execute(select(User).where(User.id == req.userId))
    user = user_res.scalar_one_or_none()
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Пользователь не найден")

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
    db.add(sub)
    await db.commit()
    await db.refresh(sub)
    logger.info("subscription_created", subscription_id=sub.id, user_id=req.userId, admin=current_user.username)
    return sub


@router.post("/{subscription_id}/use")
@limiter.limit("60/minute")
async def use_subscription(
    request: Request,
    subscription_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Internal endpoint to decrement subscription usage. Called by appointment creation."""
    result = await db.execute(
        select(Subscription).where(
            Subscription.id == subscription_id,
            Subscription.userId == current_user.id,
            Subscription.usedWashes < Subscription.totalWashes,
            or_(Subscription.validUntil == None, Subscription.validUntil >= datetime.now().isoformat()[:10]),
        ).with_for_update()
    )
    sub = result.scalar_one_or_none()
    if not sub:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Активный абонемент не найден")

    sub.usedWashes += 1
    await db.commit()
    await db.refresh(sub)
    return {"ok": True, "remaining": sub.totalWashes - sub.usedWashes}


@router.get("/stats", response_model=SubscriptionStatsResponse)
@limiter.limit("60/minute")
async def get_subscription_stats(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Returns subscription stats for the current user."""
    today = datetime.now().isoformat()[:10]
    active_res = await db.execute(
        select(func.count(Subscription.id)).where(
            Subscription.userId == current_user.id,
            Subscription.usedWashes < Subscription.totalWashes,
            or_(Subscription.validUntil == None, Subscription.validUntil >= today),
        )
    )
    active_count = active_res.scalar() or 0

    # totalSaved is approximate: sum of base prices of wash types for used subscription washes
    # We calculate based on appointments that had subscriptionId set
    saved_res = await db.execute(
        select(func.coalesce(func.sum(Appointment.originalPrice), 0)).where(
            Appointment.userId == current_user.id,
            Appointment.subscriptionId != None,
        )
    )
    total_saved = saved_res.scalar() or 0

    return SubscriptionStatsResponse(activeCount=active_count, totalSaved=total_saved)
