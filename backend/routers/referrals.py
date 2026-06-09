from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, update
from database import get_db
from db_models import User, Referral
from models import ReferralResponse, ReferralStatsResponse
from pydantic import BaseModel


class ClaimResponse(BaseModel):
    claimed: int
from services.auth_service import get_current_user
from core.limiter import limiter
from datetime import datetime

from routers.auth import _ensure_unique_referral_code

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
    # Auto-generate referral code if missing
    if not current_user.referralCode:
        code = await _ensure_unique_referral_code(db)
        await db.execute(
            update(User).where(User.id == current_user.id).values(referralCode=code)
        )
        await db.commit()
        current_user.referralCode = code

    total_res = await db.execute(
        select(func.count(Referral.id)).where(Referral.referrerId == current_user.id)
    )
    total_referrals = total_res.scalar() or 0

    claimed_res = await db.execute(
        select(func.count(Referral.id)).where(
            Referral.referrerId == current_user.id,
            Referral.rewardClaimed == True,
        )
    )
    claimed_rewards = claimed_res.scalar() or 0

    pending_rewards = total_referrals - claimed_rewards

    return ReferralStatsResponse(
        referralCode=current_user.referralCode,
        totalReferrals=total_referrals,
        claimedRewards=claimed_rewards,
        pendingRewards=pending_rewards,
    )


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
    result = await db.execute(
        select(Referral).where(Referral.referrerId == current_user.id)
    )
    referrals = result.scalars().all()

    # Fetch referred user names
    referred_ids = [r.referredId for r in referrals]
    names_map = {}
    if referred_ids:
        users_res = await db.execute(select(User).where(User.id.in_(referred_ids)))
        for u in users_res.scalars().all():
            names_map[u.id] = u.displayName

    return [
        ReferralResponse(
            id=r.id,
            referrerId=r.referrerId,
            referredId=r.referredId,
            referredName=names_map.get(r.referredId, "—"),
            rewardClaimed=r.rewardClaimed,
            createdAt=r.createdAt,
        )
        for r in referrals
    ]


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
    result = await db.execute(
        select(Referral).where(
            Referral.referrerId == current_user.id,
            Referral.rewardClaimed == False,
        ).with_for_update()
    )
    unclaimed = result.scalars().all()

    if not unclaimed:
        return {"claimed": 0}

    now = datetime.now().isoformat()
    for r in unclaimed:
        r.rewardClaimed = True
        r.createdAt = now  # update timestamp on claim

    await db.commit()
    return {"claimed": len(unclaimed)}
