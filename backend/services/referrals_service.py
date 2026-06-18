from sqlalchemy.ext.asyncio import AsyncSession

from models import User
from repositories import ReferralRepository, UserRepository
from schemas import ReferralResponse
from services.auth_service import _ensure_unique_referral_code


class ReferralsService:
    """Business logic for referral management."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._referrals = ReferralRepository(db)
        self._users = UserRepository(db)

    async def get_my_referral_stats(self, user: User) -> dict:
        if not user.referralCode:
            code = await _ensure_unique_referral_code(self._db)
            await self._users.update_fields(user.id, {"referralCode": code})
            await self._db.commit()
            user.referralCode = code

        total_referrals = await self._referrals.count_by_referrer(user.id)
        claimed_rewards = await self._referrals.count_claimed_by_referrer(user.id)
        pending_rewards = total_referrals - claimed_rewards

        return {
            "referralCode": user.referralCode,
            "totalReferrals": total_referrals,
            "claimedRewards": claimed_rewards,
            "pendingRewards": pending_rewards,
        }

    async def get_my_referrals(self, user_id: int) -> list[ReferralResponse]:
        referrals = await self._referrals.list_by_referrer(user_id)

        referred_ids = [r.referredId for r in referrals]
        names_map = {}
        if referred_ids:
            names_map = await self._users.get_display_names_by_ids(referred_ids)

        return [
            ReferralResponse(
                id=r.id,
                referrerId=r.referrerId,
                referredId=r.referredId,
                referredName=names_map.get(r.referredId, "—") or "—",
                rewardClaimed=r.rewardClaimed,
                createdAt=r.createdAt,
            )
            for r in referrals
        ]

    async def claim_rewards(self, user_id: int) -> int:
        unclaimed = await self._referrals.get_unclaimed_for_update(user_id)

        if not unclaimed:
            return 0

        referral_ids = [r.id for r in unclaimed]
        claimed = await self._referrals.mark_claimed_batch(referral_ids)
        await self._db.commit()
        return claimed
