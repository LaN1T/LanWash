from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from models import Referral
from repositories.base import BaseRepository


class ReferralRepository(BaseRepository[Referral]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Referral)

    async def count_by_referrer(self, user_id: int) -> int:
        result = await self._db.execute(
            select(func.count(Referral.id)).where(Referral.referrerId == user_id)
        )
        return result.scalar() or 0

    async def count_claimed_by_referrer(self, user_id: int) -> int:
        result = await self._db.execute(
            select(func.count(Referral.id)).where(
                Referral.referrerId == user_id,
                Referral.rewardClaimed.is_(True),
            )
        )
        return result.scalar() or 0

    async def list_by_referrer(self, user_id: int) -> list[Referral]:
        result = await self._db.execute(
            select(Referral).where(Referral.referrerId == user_id)
        )
        return list(result.scalars().all())

    async def get_unclaimed_for_update(self, user_id: int) -> list[Referral]:
        result = await self._db.execute(
            select(Referral)
            .where(
                Referral.referrerId == user_id,
                Referral.rewardClaimed.is_(False),
            )
            .with_for_update()
        )
        return list(result.scalars().all())

    async def mark_claimed_batch(self, referral_ids: list[int]) -> int:
        if not referral_ids:
            return 0
        result = await self._db.execute(
            update(Referral)
            .where(Referral.id.in_(referral_ids))
            .values(rewardClaimed=True)
        )
        return result.rowcount or 0
