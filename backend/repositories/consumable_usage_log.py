from collections.abc import AsyncGenerator
from datetime import datetime

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Appointment, Consumable, ConsumableUsageLog
from repositories.base import BaseRepository


class ConsumableUsageLogRepository(BaseRepository[ConsumableUsageLog]):
    def __init__(self, db: AsyncSession) -> None:
        super().__init__(db, ConsumableUsageLog)

    async def list_by_date_range(
        self, date_from: datetime | None, date_to: datetime | None
    ) -> list[ConsumableUsageLog]:
        stmt = select(ConsumableUsageLog)
        if date_from:
            stmt = stmt.where(ConsumableUsageLog.timestamp >= date_from)
        if date_to:
            stmt = stmt.where(ConsumableUsageLog.timestamp <= date_to)
        stmt = stmt.order_by(ConsumableUsageLog.timestamp.desc())
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def sum_usage_since(self, consumable_id: str, since: datetime) -> float:
        result = await self._db.execute(
            select(func.coalesce(func.sum(ConsumableUsageLog.quantityUsed), 0.0)).where(
                ConsumableUsageLog.consumableId == consumable_id,
                ConsumableUsageLog.timestamp >= since,
            )
        )
        return result.scalar() or 0.0

    async def sum_usage_grouped_since(self, since: datetime) -> dict[str, float]:
        result = await self._db.execute(
            select(
                ConsumableUsageLog.consumableId,
                func.coalesce(func.sum(ConsumableUsageLog.quantityUsed), 0.0),
            )
            .where(ConsumableUsageLog.timestamp >= since)
            .group_by(ConsumableUsageLog.consumableId)
        )
        return {cid: float(total) for cid, total in result.all()}

    async def stream_usage_with_appointment_in_period(
        self, start: datetime, end: datetime
    ) -> AsyncGenerator[tuple[str, str, str, float, str, str | None], None]:
        query = (
            select(
                Consumable.id,
                Consumable.name,
                Consumable.unit,
                ConsumableUsageLog.quantityUsed,
                ConsumableUsageLog.appointmentId,
                Appointment.promoId,
            )
            .join(Consumable, ConsumableUsageLog.consumableId == Consumable.id)
            .join(Appointment, ConsumableUsageLog.appointmentId == Appointment.id)
            .where(
                and_(
                    Appointment.dateTime >= start,
                    Appointment.dateTime < end,
                    Appointment.status == "completed",
                )
            )
        )
        result = await self._db.stream(query)
        async for row in result:
            yield row
