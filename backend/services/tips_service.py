import json
from datetime import datetime
from typing import Optional

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from models import Appointment, Tip
from repositories.appointment import AppointmentRepository
from repositories.tip import TipRepository
from schemas import TipCreateRequest


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
        self._appointments = AppointmentRepository(db)
        self._tips = TipRepository(db)

    async def create_tip(self, data: TipCreateRequest, current_username: str) -> Tip:
        appointment = await self._appointments.get_by_id(data.appointmentId)
        if not appointment:
            raise AppointmentNotFoundError("Запись не найдена")
        if appointment.status != "completed":
            raise ValueError("Можно оставить чаевые только за завершённую мойку")
        if appointment.ownerUsername != current_username:
            raise PermissionError("Нельзя оставить чаевые за чужую запись")

        washer_username = self._first_washer(appointment.assignedWasher)
        if not washer_username:
            raise ValueError("На эту запись не назначен мойщик")

        if await self._tips.get_by_appointment_and_washer(
            data.appointmentId, washer_username
        ):
            raise DuplicateTipError("Чаевые на эту запись уже оставлены")

        tip = Tip(
            appointmentId=data.appointmentId,
            washerUsername=washer_username,
            amount=data.amount,
            method=data.method,
            status="pending",
            createdAt=datetime.utcnow(),
        )
        await self._tips.add(tip)
        try:
            await self._db.commit()
        except IntegrityError:
            await self._db.rollback()
            raise
        await self._db.refresh(tip)
        return tip

    async def list_my_tips(
        self, username: str
    ) -> list[tuple[Tip, Optional[Appointment]]]:
        return await self._tips.list_with_appointments(username)

    async def get_tip_stats(self, username: str) -> dict:
        return await self._tips.get_stats(username)

    async def mark_tip_paid(
        self, tip_id: int, current_username: str, is_admin: bool
    ) -> Tip:
        tip = await self._tips.get_by_id(tip_id)
        if not tip:
            raise TipNotFoundError("Чаевые не найдены")

        if current_username != tip.washerUsername and not is_admin:
            raise TipAccessDeniedError("Нет прав на изменение статуса")

        update_result = await self._tips.mark_paid(tip_id)
        await self._db.commit()
        if update_result == 0:
            raise ValueError("Чаевые уже отмечены как полученные")

        await self._db.refresh(tip)
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
