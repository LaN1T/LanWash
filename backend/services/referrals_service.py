from datetime import datetime

from db_models import Referral, User
from models import ReferralResponse
from services.auth_service import _ensure_unique_referral_code
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession


class ReferralsService:
    """Business logic for referral management."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_my_referral_stats(self, user: User) -> dict:
        if not user.referralCode:
            code = await _ensure_unique_referral_code(self._db)
            await self._db.execute(
                update(User).where(User.id == user.id).values(referralCode=code)
            )
            await self._db.commit()
            user.referralCode = code

        total_res = await self._db.execute(
            select(func.count(Referral.id)).where(Referral.referrerId == user.id)
        )
        total_referrals = total_res.scalar() or 0

        claimed_res = await self._db.execute(
            select(func.count(Referral.id)).where(
                Referral.referrerId == user.id,
                Referral.rewardClaimed == True,
            )
        )
        claimed_rewards = claimed_res.scalar() or 0

        pending_rewards = total_referrals - claimed_rewards

        return {
            "referralCode": user.referralCode,
            "totalReferrals": total_referrals,
            "claimedRewards": claimed_rewards,
            "pendingRewards": pending_rewards,
        }

    async def get_my_referrals(self, user_id: int) -> list[ReferralResponse]:
        result = await self._db.execute(
            select(Referral).where(Referral.referrerId == user_id)
        )
        referrals = result.scalars().all()

        referred_ids = [r.referredId for r in referrals]
        names_map = {}
        if referred_ids:
            users_res = await self._db.execute(
                select(User).where(User.id.in_(referred_ids))
            )
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

    async def claim_rewards(self, user_id: int) -> int:
        result = await self._db.execute(
            select(Referral)
            .where(
                Referral.referrerId == user_id,
                Referral.rewardClaimed == False,
            )
            .with_for_update()
        )
        unclaimed = result.scalars().all()

        if not unclaimed:
            return 0

        now = datetime.now().isoformat()
        for r in unclaimed:
            r.rewardClaimed = True
            r.createdAt = now

        await self._db.commit()
        return len(unclaimed)
