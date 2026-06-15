from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Tip
from repositories.base import BaseRepository


class TipRepository(BaseRepository[Tip]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Tip)

    async def get_by_appointment_and_washer(self, appointment_id: str, washer_username: str) -> Tip | None:
        result = await self._db.execute(
            select(Tip).where(
                Tip.appointmentId == appointment_id,
                Tip.washerUsername == washer_username,
            )
        )
        return result.scalar_one_or_none()

    async def list_with_appointments(self, username: str):
        from models import Appointment
        result = await self._db.execute(
            select(Tip, Appointment)
            .join(Appointment, Tip.appointmentId == Appointment.id, isouter=True)
            .where(Tip.washerUsername == username)
            .order_by(Tip.createdAt.desc())
        )
        return result.all()

    async def get_stats(self, username: str) -> dict:
        total_res = await self._db.execute(
            select(func.count(Tip.id)).where(Tip.washerUsername == username)
        )
        total_tips = total_res.scalar() or 0

        total_amount_res = await self._db.execute(
            select(func.sum(Tip.amount)).where(
                Tip.washerUsername == username,
                Tip.status == "paid",
            )
        )
        total_amount = total_amount_res.scalar() or 0

        pending_amount_res = await self._db.execute(
            select(func.sum(Tip.amount)).where(
                Tip.washerUsername == username,
                Tip.status == "pending",
            )
        )
        pending_amount = pending_amount_res.scalar() or 0

        return {
            "totalTips": total_tips,
            "totalAmount": total_amount,
            "pendingAmount": pending_amount,
        }
