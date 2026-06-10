import uuid
from datetime import datetime, timedelta
from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, status, Response, Request
from core.limiter import limiter
from sqlalchemy.ext.asyncio import AsyncSession
from database import get_db
from models import SubscriptionCreateRequest, SubscriptionResponse, SubscriptionStatsResponse
from db_models import User
from services.auth_service import get_current_user, check_roles
from services.subscriptions_service import (
    SubscriptionsService,
    SubscriptionNotFoundError,
    UserNotFoundError,
)
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
    svc = SubscriptionsService(db)
    return await svc.get_my_subscriptions(current_user.id)


@router.post("/", response_model=SubscriptionResponse, status_code=status.HTTP_201_CREATED)
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
    """Internal endpoint to decrement subscription usage. Called by appointment creation."""
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
