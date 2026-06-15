from datetime import datetime

from sqlalchemy import and_, delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Shift, User
from schemas import ShiftMoveRequest, ShiftRequest


class ShiftNotFoundError(Exception):
    pass


class ShiftAccessDeniedError(Exception):
    pass


class ShiftsService:
    """Business logic for shift management."""

    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def list_shifts(
        self, start_date: str, end_date: str, user_id: int, is_admin: bool
    ) -> list[Shift]:
        stmt = select(Shift).where(and_(Shift.date >= start_date, Shift.date <= end_date))
        if not is_admin:
            stmt = stmt.where(Shift.userId == user_id)
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def list_today_shifts(self, today: str, user_id: int, is_admin: bool) -> list[Shift]:
        stmt = (
            select(Shift)
            .where(and_(Shift.date == today, Shift.status == "confirmed"))
            .order_by(Shift.startTime.asc())
        )
        if not is_admin:
            stmt = stmt.where(Shift.userId == user_id)
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def list_current_shifts(
        self, today: str, current_minutes: int, user_id: int, is_admin: bool
    ) -> list[dict]:
        stmt = select(Shift, User).join(User, Shift.userId == User.id).where(
            and_(
                Shift.date == today,
                Shift.status == "confirmed",
            )
        )
        if not is_admin:
            stmt = stmt.where(Shift.userId == user_id)

        result = await self._db.execute(stmt)
        on_duty = []
        for shift, user in result.all():
            start_m = self._time_to_minutes(shift.startTime)
            end_m = self._time_to_minutes(shift.endTime)
            if start_m <= current_minutes <= end_m:
                on_duty.append({
                    "shiftId": shift.id,
                    "userId": user.id,
                    "name": user.displayName,
                    "phone": user.phone,
                    "start": shift.startTime,
                    "end": shift.endTime,
                })
        return on_duty

    async def list_my_shifts(self, user_id: int, limit: int) -> list[Shift]:
        stmt = (
            select(Shift)
            .where(Shift.userId == user_id)
            .order_by(Shift.date.asc())
            .limit(limit)
        )
        result = await self._db.execute(stmt)
        return list(result.scalars().all())

    async def create_shift(
        self, req: ShiftRequest, caller_username: str, is_admin: bool
    ) -> Shift:
        user_res = await self._db.execute(select(User).where(User.id == req.userId))
        target_user = user_res.scalar_one_or_none()
        if not target_user:
            raise ValueError("Пользователь не найден")

        if not is_admin:
            if target_user.username != caller_username:
                raise PermissionError("Можно редактировать только свои смены")

        now = datetime.now().isoformat()
        status_val = "confirmed" if is_admin else "pending"

        existing_res = await self._db.execute(
            select(Shift).where(and_(Shift.userId == req.userId, Shift.date == req.date))
        )
        existing = existing_res.scalar_one_or_none()

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
        self._db.add(shift)
        await self._db.commit()
        await self._db.refresh(shift)
        return shift

    async def approve_shift(self, shift_id: int) -> Shift:
        res = await self._db.execute(select(Shift).where(Shift.id == shift_id))
        shift = res.scalar_one_or_none()
        if not shift:
            raise ShiftNotFoundError()
        shift.status = "confirmed"
        shift.updatedAt = datetime.now().isoformat()
        await self._db.commit()
        await self._db.refresh(shift)
        return shift

    async def reject_shift(self, shift_id: int) -> Shift:
        res = await self._db.execute(select(Shift).where(Shift.id == shift_id))
        shift = res.scalar_one_or_none()
        if not shift:
            raise ShiftNotFoundError()
        shift.status = "rejected"
        shift.updatedAt = datetime.now().isoformat()
        await self._db.commit()
        await self._db.refresh(shift)
        return shift

    async def reopen_shift(self, shift_id: int) -> Shift:
        res = await self._db.execute(select(Shift).where(Shift.id == shift_id))
        shift = res.scalar_one_or_none()
        if not shift:
            raise ShiftNotFoundError()
        shift.status = "pending"
        shift.updatedAt = datetime.now().isoformat()
        await self._db.commit()
        await self._db.refresh(shift)
        return shift

    async def delete_shift(self, shift_id: int, caller_username: str, is_admin: bool) -> None:
        res = await self._db.execute(select(Shift).where(Shift.id == shift_id))
        shift = res.scalar_one_or_none()
        if not shift:
            raise ShiftNotFoundError()

        if not is_admin:
            user_res = await self._db.execute(select(User).where(User.id == shift.userId))
            target_user = user_res.scalar_one_or_none()
            if not target_user or target_user.username != caller_username:
                raise ShiftAccessDeniedError("Можно удалять только свои смены")
            if shift.status == "confirmed":
                raise ShiftAccessDeniedError("Нельзя удалить подтверждённую смену")

        await self._db.execute(delete(Shift).where(Shift.id == shift_id))
        await self._db.commit()

    async def move_shift(
        self, shift_id: int, req: ShiftMoveRequest, caller_username: str, is_admin: bool
    ) -> Shift:
        if not is_admin:
            raise PermissionError("Только администратор может перемещать смены")

        shift_res = await self._db.execute(select(Shift).where(Shift.id == shift_id))
        shift = shift_res.scalar_one_or_none()
        if not shift:
            raise ShiftNotFoundError()

        user_res = await self._db.execute(select(User).where(User.id == req.targetUserId))
        target_user = user_res.scalar_one_or_none()
        if not target_user:
            raise ValueError("Пользователь не найден")

        now = datetime.now().isoformat()

        # Удаляем смену в целевой ячейке, если она есть (перезапись).
        await self._db.execute(
            delete(Shift).where(
                and_(Shift.userId == req.targetUserId, Shift.date == req.targetDate)
            )
        )

        # Удаляем исходную смену.
        await self._db.execute(delete(Shift).where(Shift.id == shift_id))

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
        self._db.add(new_shift)
        await self._db.commit()
        await self._db.refresh(new_shift)
        return new_shift

    @staticmethod
    def _time_to_minutes(time_str: str) -> int:
        h, m = map(int, time_str.split(':'))
        return h * 60 + m
