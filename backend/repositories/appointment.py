from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Appointment, Shift, WashType
from repositories.base import BaseRepository


class AppointmentRepository(BaseRepository[Appointment]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Appointment)

    async def count_completed_by_owner(self, username: str) -> int:
        result = await self._db.execute(
            select(func.count(Appointment.id)).where(
                Appointment.ownerUsername == username,
                Appointment.status == "completed",
            )
        )
        return result.scalar() or 0

    async def sum_paid_price_completed_by_owner(self, username: str) -> int:
        result = await self._db.execute(
            select(func.sum(Appointment.paidPrice)).where(
                Appointment.ownerUsername == username,
                Appointment.status == "completed",
            )
        )
        return result.scalar() or 0

    async def get_favorite_wash_type_completed_by_owner(
        self, username: str
    ) -> str | None:
        result = await self._db.execute(
            select(WashType.name, func.count(Appointment.id))
            .join(Appointment, Appointment.washTypeId == WashType.id)
            .where(
                Appointment.ownerUsername == username,
                Appointment.status == "completed",
            )
            .group_by(WashType.name)
            .order_by(func.count(Appointment.id).desc())
            .limit(1)
        )
        row = result.first()
        return row[0] if row else None

    async def list_completed_assigned_washer_like(
        self, username_pattern: str, escape: str = "\\"
    ) -> list[Appointment]:
        result = await self._db.execute(
            select(Appointment).where(
                Appointment.assignedWasher.like(
                    f'%"{username_pattern}"%', escape=escape
                ),
                Appointment.status == "completed",
            )
        )
        return list(result.scalars().all())

    async def list_completed_by_shift_for_user(self, user_id: int) -> list[Appointment]:
        appt_time = func.substr(Appointment.dateTime, 12, 5)
        result = await self._db.execute(
            select(Appointment)
            .join(
                Shift,
                and_(
                    Shift.userId == user_id,
                    Shift.date == Appointment.date,
                    appt_time >= Shift.startTime,
                    appt_time <= Shift.endTime,
                ),
            )
            .where(Appointment.status == "completed")
        )
        return list(result.scalars().all())
