from collections.abc import AsyncGenerator
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Time, and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Appointment, AppointmentWasher, Shift, WashType
from repositories.base import BaseRepository


class AppointmentRepository(BaseRepository[Appointment]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, Appointment)

    async def list_for_day(
        self,
        day_start: datetime,
        day_end: datetime,
        exclude_appt_id: str | None = None,
    ) -> list[Appointment]:
        query = select(Appointment).where(
            and_(
                Appointment.dateTime >= day_start,
                Appointment.dateTime <= day_end,
                Appointment.status != "cancelled",
            )
        )
        if exclude_appt_id:
            query = query.where(Appointment.id != exclude_appt_id)
        result = await self._db.execute(query)
        return list(result.scalars().all())

    async def count_completed_by_owner(self, username: str) -> int:
        result = await self._db.execute(
            select(func.count(Appointment.id)).where(
                Appointment.ownerUsername == username,
                Appointment.status == "completed",
            )
        )
        return result.scalar() or 0

    async def sum_paid_price_completed_by_owner(self, username: str) -> Decimal:
        result = await self._db.execute(
            select(func.sum(Appointment.paidPrice)).where(
                Appointment.ownerUsername == username,
                Appointment.status == "completed",
            )
        )
        return result.scalar() or Decimal(0)

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

    async def list_completed_assigned_to_washer(
        self, username: str
    ) -> list[Appointment]:
        result = await self._db.execute(
            select(Appointment)
            .join(AppointmentWasher)
            .where(
                AppointmentWasher.washerUsername == username,
                Appointment.status == "completed",
            )
        )
        return list(result.scalars().all())

    async def list_completed_by_shift_for_user(self, user_id: int) -> list[Appointment]:
        appt_time = func.cast(Appointment.dateTime, Time)
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

    async def list_completed_datetimes_in_period(
        self, start: datetime, end: datetime
    ) -> list[tuple[datetime]]:
        result = await self._db.execute(
            select(Appointment.dateTime).where(
                Appointment.status == "completed",
                Appointment.dateTime >= start,
                Appointment.dateTime < end,
            )
        )
        return list(result.all())

    async def get_status_counts_in_period(
        self, start: datetime, end: datetime
    ) -> list[tuple[str, int]]:
        result = await self._db.execute(
            select(Appointment.status, func.count(Appointment.id))
            .where(
                Appointment.dateTime >= start,
                Appointment.dateTime < end,
            )
            .group_by(Appointment.status)
        )
        return [(row[0], row[1]) for row in result.all()]

    async def get_revenue_stats_in_period(
        self, start: datetime, end: datetime
    ) -> tuple[Decimal | None, Decimal | None]:
        result = await self._db.execute(
            select(
                func.sum(Appointment.paidPrice), func.avg(Appointment.paidPrice)
            ).where(
                Appointment.dateTime >= start,
                Appointment.dateTime < end,
                Appointment.status == "completed",
            )
        )
        row = result.first()
        return (row[0], row[1]) if row else (None, None)

    async def list_completed_owners_datetimes_in_period(
        self, start: datetime, end: datetime
    ) -> list[tuple[str | None, datetime]]:
        result = await self._db.execute(
            select(Appointment.ownerUsername, Appointment.dateTime)
            .where(
                Appointment.dateTime >= start,
                Appointment.dateTime < end,
                Appointment.status == "completed",
            )
            .order_by(Appointment.dateTime.asc())
        )
        return list(result.all())

    async def get_first_visit_dates(self) -> dict[str | None, datetime]:
        result = await self._db.execute(
            select(Appointment.ownerUsername, func.min(Appointment.dateTime))
            .where(Appointment.status == "completed")
            .group_by(Appointment.ownerUsername)
        )
        return {row[0]: row[1] for row in result.all()}

    async def list_period_details(
        self, start: datetime, end: datetime
    ) -> list[tuple[date, str, int | None]]:
        result = await self._db.execute(
            select(Appointment.date, Appointment.status, Appointment.paidPrice).where(
                Appointment.dateTime >= start,
                Appointment.dateTime < end,
            )
        )
        return list(result.all())

    async def list_completed_washer_paid_in_period(
        self, start: datetime, end: datetime
    ) -> list[tuple[str | None, int | None]]:
        result = await self._db.execute(
            select(AppointmentWasher.washerUsername, Appointment.paidPrice)
            .join(Appointment)
            .where(
                Appointment.dateTime >= start,
                Appointment.dateTime < end,
                Appointment.status == "completed",
            )
        )
        return list(result.all())

    async def list_completed_owner_stats_in_period(
        self, start: datetime, end: datetime, limit: int
    ) -> list[tuple[str | None, int, Decimal | None]]:
        result = await self._db.execute(
            select(
                Appointment.ownerUsername,
                func.count(Appointment.id),
                func.sum(Appointment.paidPrice),
            )
            .where(
                Appointment.dateTime >= start,
                Appointment.dateTime < end,
                Appointment.status == "completed",
                Appointment.ownerUsername.isnot(None),
            )
            .group_by(Appointment.ownerUsername)
            .order_by(func.count(Appointment.id).desc())
            .limit(limit)
        )
        return list(result.all())

    async def list_completed_by_owners(self, usernames: list[str]) -> list[Appointment]:
        if not usernames:
            return []
        result = await self._db.execute(
            select(Appointment)
            .where(
                Appointment.ownerUsername.in_(usernames),
                Appointment.status == "completed",
            )
            .order_by(Appointment.dateTime.asc())
        )
        return list(result.scalars().all())

    async def list_scheduled_in_period(
        self, start: datetime, end: datetime
    ) -> list[Appointment]:
        result = await self._db.execute(
            select(Appointment).where(
                Appointment.status == "scheduled",
                Appointment.dateTime >= start,
                Appointment.dateTime < end,
            )
        )
        return list(result.scalars().all())

    async def get_car_model_stats_in_period(
        self, start: datetime, end: datetime
    ) -> list[tuple[str | None, Decimal | None, int]]:
        result = await self._db.execute(
            select(
                Appointment.carModel,
                func.avg(Appointment.paidPrice).label("avgCheck"),
                func.count(Appointment.id).label("visitCount"),
            )
            .where(
                and_(
                    Appointment.status == "completed",
                    Appointment.dateTime >= start,
                    Appointment.dateTime < end,
                )
            )
            .group_by(Appointment.carModel)
        )
        return [(row[0], row[1] or Decimal(0), row[2] or 0) for row in result.all()]

    async def stream_popular_services_fields_in_period(
        self, start: datetime, end: datetime
    ) -> AsyncGenerator[tuple[str | None, str | None, str | None], None]:
        query = select(
            Appointment.additionalServices,
            Appointment.promoId,
            Appointment.washTypeId,
        ).where(
            and_(
                Appointment.status == "completed",
                Appointment.dateTime >= start,
                Appointment.dateTime < end,
            )
        )
        result = await self._db.stream(query)
        async for row in result:
            yield row

    async def count_in_period(self, start: datetime, end: datetime) -> int:
        result = await self._db.execute(
            select(func.count(Appointment.id)).where(
                Appointment.dateTime >= start,
                Appointment.dateTime < end,
            )
        )
        return result.scalar() or 0

    async def get_completed_stats_in_period(
        self, start: datetime, end: datetime
    ) -> tuple[int, Decimal | None, Decimal | None]:
        result = await self._db.execute(
            select(
                func.count(Appointment.id),
                func.sum(Appointment.paidPrice),
                func.avg(Appointment.paidPrice),
            ).where(
                and_(
                    Appointment.dateTime >= start,
                    Appointment.dateTime < end,
                    Appointment.status == "completed",
                )
            )
        )
        row = result.first()
        return (
            row[0] or 0,
            row[1],
            row[2],
        )

    async def get_box_occupancy_in_period(
        self, start: datetime, end: datetime
    ) -> list[tuple[int | None, int]]:
        result = await self._db.execute(
            select(Appointment.box_index, func.count(Appointment.id))
            .where(
                and_(
                    Appointment.dateTime >= start,
                    Appointment.dateTime < end,
                    Appointment.status == "completed",
                )
            )
            .group_by(Appointment.box_index)
        )
        return [(row[0], row[1] or 0) for row in result.all()]

    async def list_wash_type_and_additional_services_in_period(
        self, start: datetime, end: datetime
    ) -> list[tuple[str | None, str | None]]:
        result = await self._db.execute(
            select(Appointment.washTypeId, Appointment.additionalServices).where(
                and_(
                    Appointment.dateTime >= start,
                    Appointment.dateTime < end,
                    Appointment.status == "completed",
                )
            )
        )
        return list(result.all())
