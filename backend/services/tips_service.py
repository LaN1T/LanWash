import json
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from db_models import Appointment, Tip
from models import TipCreateRequest


class TipNotFoundError(Exception):
    pass


class TipAccessDeniedError(Exception):
    pass


class AppointmentNotFoundError(Exception):
    pass


class DuplicateTipError(Exception):
    pass


class TipsService:
    """Business logic for tips."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def create_tip(self, data: TipCreateRequest, current_username: str) -> Tip:
        result = await self._db.execute(
            select(Appointment).where(Appointment.id == data.appointmentId)
        )
        appointment = result.scalar_one_or_none()
        if not appointment:
            raise AppointmentNotFoundError("Запись не найдена")
        if appointment.status != "completed":
            raise ValueError("Можно оставить чаевые только за завершённую мойку")
        if appointment.ownerUsername != current_username:
            raise PermissionError("Нельзя оставить чаевые за чужую запись")

        washer_username = self._first_washer(appointment.assignedWasher)
        if not washer_username:
            raise ValueError("На эту запись не назначен мойщик")

        existing = await self._db.execute(
            select(Tip).where(
                Tip.appointmentId == data.appointmentId,
                Tip.washerUsername == washer_username,
            )
        )
        if existing.scalar_one_or_none():
            raise DuplicateTipError("Чаевые на эту запись уже оставлены")

        tip = Tip(
            appointmentId=data.appointmentId,
            washerUsername=washer_username,
            amount=data.amount,
            method=data.method,
            status="pending",
            createdAt=datetime.now(timezone.utc).isoformat(),
        )
        self._db.add(tip)
        try:
            await self._db.commit()
        except IntegrityError:
            await self._db.rollback()
            raise
        await self._db.refresh(tip)
        return tip

    async def list_my_tips(self, username: str) -> list[tuple[Tip, Optional[Appointment]]]:
        stmt = (
            select(Tip, Appointment)
            .join(Appointment, Tip.appointmentId == Appointment.id, isouter=True)
            .where(Tip.washerUsername == username)
            .order_by(Tip.createdAt.desc())
        )
        result = await self._db.execute(stmt)
        return result.all()

    async def get_tip_stats(self, username: str) -> dict:
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

    async def mark_tip_paid(self, tip_id: int, current_username: str, is_admin: bool) -> Tip:
        result = await self._db.execute(select(Tip).where(Tip.id == tip_id))
        tip = result.scalar_one_or_none()
        if not tip:
            raise TipNotFoundError("Чаевые не найдены")

        if current_username != tip.washerUsername and not is_admin:
            raise TipAccessDeniedError("Нет прав на изменение статуса")

        update_result = await self._db.execute(
            update(Tip)
            .where(Tip.id == tip_id, Tip.status == "pending")
            .values(status="paid")
        )
        await self._db.commit()
        if update_result.rowcount == 0:
            raise ValueError("Чаевые уже отмечены как полученные")

        await self._db.refresh(tip)
        tip.status = "paid"
        return tip

    @staticmethod
    def _first_washer(assigned_washer_raw: str) -> Optional[str]:
        try:
            washers = json.loads(assigned_washer_raw) if assigned_washer_raw else []
            if isinstance(washers, list) and washers:
                return washers[0]
        except json.JSONDecodeError:
            if assigned_washer_raw and assigned_washer_raw != "[]":
                return assigned_washer_raw
        return None
