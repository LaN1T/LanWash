from datetime import date, datetime, time

from sqlalchemy.ext.asyncio import AsyncSession

from models import Shift
from repositories.shift import ShiftRepository
from repositories.user import UserRepository
from schemas import ShiftMoveRequest, ShiftRequest


class ShiftNotFoundError(Exception):
    pass


class ShiftAccessDeniedError(Exception):
    pass


class ShiftsService:
    """Business logic for shift management."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db
        self._shifts = ShiftRepository(db)
        self._users = UserRepository(db)

    async def list_shifts(
        self, start_date: date, end_date: date, user_id: int, is_admin: bool
    ) -> list[Shift]:
        return await self._shifts.list_for_range(
            start_date, end_date, user_id=None if is_admin else user_id
        )

    async def list_today_shifts(
        self, today: date, user_id: int, is_admin: bool
    ) -> list[Shift]:
        return await self._shifts.list_today(
            today, user_id=None if is_admin else user_id
        )

    async def list_current_shifts(
        self, today: date, current_minutes: int, user_id: int, is_admin: bool
    ) -> list[dict]:
        rows = await self._shifts.list_current(
            today, user_id=None if is_admin else user_id
        )
        on_duty = []
        for shift, user in rows:
            start_m = self._time_to_minutes(shift.startTime)
            end_m = self._time_to_minutes(shift.endTime)
            if start_m <= current_minutes <= end_m:
                on_duty.append(
                    {
                        "shiftId": shift.id,
                        "userId": user.id,
                        "name": user.displayName,
                        "phone": user.phone,
                        "start": shift.startTime,
                        "end": shift.endTime,
                    }
                )
        return on_duty

    async def list_my_shifts(self, user_id: int, limit: int) -> list[Shift]:
        return await self._shifts.list_for_user(user_id, limit)

    async def create_shift(
        self, req: ShiftRequest, caller_username: str, is_admin: bool
    ) -> Shift:
        target_user = await self._users.get_by_id(req.userId)
        if not target_user:
            raise ValueError("Пользователь не найден")

        if not is_admin:
            if target_user.username != caller_username:
                raise PermissionError("Можно редактировать только свои смены")

        now = datetime.now()
        status_val = "confirmed" if is_admin else "pending"

        existing = await self._shifts.get_by_user_and_date(req.userId, req.date)

        if existing:
            if not is_admin and existing.status == "confirmed":
                raise PermissionError(
                    "Подтверждённую смену может изменить только администратор"
                )
            existing.startTime = req.startTime
            existing.endTime = req.endTime
            existing.status = status_val
            existing.createdBy = caller_username
            existing.updatedAt = now
            await self._db.commit()
            await self._db.refresh(existing)
            return existing

        shift = Shift(
            userId=req.userId,
            date=req.date,
            startTime=req.startTime,
            endTime=req.endTime,
            status=status_val,
            createdBy=caller_username,
            createdAt=now,
            updatedAt=now,
        )
        await self._shifts.add(shift)
        await self._db.commit()
        await self._db.refresh(shift)
        return shift

    async def approve_shift(self, shift_id: int) -> Shift:
        shift = await self._shifts.get_by_id(shift_id)
        if not shift:
            raise ShiftNotFoundError()
        shift.status = "confirmed"
        shift.updatedAt = datetime.now()
        await self._db.commit()
        await self._db.refresh(shift)
        return shift

    async def reject_shift(self, shift_id: int) -> Shift:
        shift = await self._shifts.get_by_id(shift_id)
        if not shift:
            raise ShiftNotFoundError()
        shift.status = "rejected"
        shift.updatedAt = datetime.now()
        await self._db.commit()
        await self._db.refresh(shift)
        return shift

    async def reopen_shift(self, shift_id: int) -> Shift:
        shift = await self._shifts.get_by_id(shift_id)
        if not shift:
            raise ShiftNotFoundError()
        shift.status = "pending"
        shift.updatedAt = datetime.now()
        await self._db.commit()
        await self._db.refresh(shift)
        return shift

    async def delete_shift(
        self, shift_id: int, caller_username: str, is_admin: bool
    ) -> None:
        shift = await self._shifts.get_by_id(shift_id)
        if not shift:
            raise ShiftNotFoundError()

        if not is_admin:
            target_user = await self._users.get_by_id(shift.userId)
            if not target_user or target_user.username != caller_username:
                raise ShiftAccessDeniedError("Можно удалять только свои смены")
            if shift.status == "confirmed":
                raise ShiftAccessDeniedError("Нельзя удалить подтверждённую смену")

        await self._shifts.delete(shift)
        await self._db.commit()

    async def move_shift(
        self, shift_id: int, req: ShiftMoveRequest, caller_username: str, is_admin: bool
    ) -> Shift:
        if not is_admin:
            raise PermissionError("Только администратор может перемещать смены")

        shift = await self._shifts.get_by_id(shift_id)
        if not shift:
            raise ShiftNotFoundError()

        target_user = await self._users.get_by_id(req.targetUserId)
        if not target_user:
            raise ValueError("Пользователь не найден")

        now = datetime.now()

        # Удаляем смену в целевой ячейке, если она есть (перезапись).
        await self._shifts.delete_for_user_and_date(req.targetUserId, req.targetDate)

        # Удаляем исходную смену.
        await self._shifts.delete_by_id(shift_id)

        new_shift = Shift(
            userId=req.targetUserId,
            date=req.targetDate,
            startTime=shift.startTime,
            endTime=shift.endTime,
            status=shift.status,
            createdBy=shift.createdBy,
            createdAt=shift.createdAt,
            updatedAt=now,
        )
        await self._shifts.add(new_shift)
        await self._db.commit()
        await self._db.refresh(new_shift)
        return new_shift

    @staticmethod
    def _time_to_minutes(t: time | str) -> int:
        if isinstance(t, time):
            return t.hour * 60 + t.minute
        h, m = map(int, t.split(":"))
        return h * 60 + m
