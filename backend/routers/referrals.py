from core.limiter import limiter
from database import get_db
from db_models import User
from fastapi import APIRouter, Depends, Request
from models import ReferralResponse, ReferralStatsResponse
from pydantic import BaseModel
from services.auth_service import get_current_user
from services.referrals_service import ReferralsService
from sqlalchemy.ext.asyncio import AsyncSession


class ClaimResponse(BaseModel):
    claimed: int


router = APIRouter(
    prefix="/api/referrals",
    tags=["referrals"],
)


@router.get(
    "/my",
    response_model=ReferralStatsResponse,
    summary="Статистика рефералов текущего пользователя",
)
@limiter.limit("60/minute")
async def get_my_referral_stats(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = ReferralsService(db)
    stats = await svc.get_my_referral_stats(current_user)
    return ReferralStatsResponse(**stats)


@router.get(
    "/list",
    response_model=list[ReferralResponse],
    summary="Список рефералов текущего пользователя",
)
@limiter.limit("60/minute")
async def get_my_referrals(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = ReferralsService(db)
    return await svc.get_my_referrals(current_user.id)


@router.post(
    "/claim",
    response_model=ClaimResponse,
    summary="Получить награды за непогашенные рефералы",
)
@limiter.limit("10/minute")
async def claim_rewards(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = ReferralsService(db)
    claimed = await svc.claim_rewards(current_user.id)
    return {"claimed": claimed}
