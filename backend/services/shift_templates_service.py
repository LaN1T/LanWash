from datetime import datetime, timedelta
from typing import List

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from models import ShiftTemplate, User
from repositories.shift_template import ShiftTemplateRepository
from schemas import (
    ShiftRequest,
    ShiftTemplateApplyRequest,
    ShiftTemplateCreateRequest,
    ShiftTemplateResponse,
    ShiftTemplateSlot,
    ShiftTemplateUpdateRequest,
)
from services.shifts_service import ShiftsService


class ShiftTemplatesService:
    def __init__(self, db: AsyncSession, current_user: User) -> None:
        self._db = db
        self._current_user = current_user
        self._templates = ShiftTemplateRepository(db)
        self._shifts_service = ShiftsService(db)

    def _is_admin(self) -> bool:
        return self._current_user.role == "admin"

    async def _ensure_owner_access(self, template: ShiftTemplate) -> None:
        if template.ownerUsername != self._current_user.username.lower() and not self._is_admin():
            raise HTTPException(status_code=403, detail="Доступ запрещён")

    async def list_templates(self) -> List[ShiftTemplateResponse]:
        rows = await self._templates.list_for_owner(
            self._current_user.username.lower(),
            include_all=self._is_admin(),
        )
        return [ShiftTemplateResponse.model_validate(r) for r in rows]

    async def create_template(
        self, payload: ShiftTemplateCreateRequest
    ) -> ShiftTemplateResponse:
        owner = self._current_user.username.lower()
        if payload.isDefault:
            await self._templates.clear_owner_default(owner)

        template = ShiftTemplate(
            ownerUsername=owner,
            name=payload.name,
            isDefault=payload.isDefault,
            slots=[s.model_dump() for s in payload.slots],
        )
        await self._templates.add(template)
        await self._db.commit()
        await self._db.refresh(template)
        return ShiftTemplateResponse.model_validate(template)

    async def update_template(
        self, template_id: int, payload: ShiftTemplateUpdateRequest
    ) -> ShiftTemplateResponse:
        template = await self._templates.get_by_id(template_id)
        if template is None:
            raise HTTPException(status_code=404, detail="Шаблон не найден")
        await self._ensure_owner_access(template)

        if payload.name is not None:
            template.name = payload.name
        if payload.slots is not None:
            template.slots = [s.model_dump() for s in payload.slots]
        if payload.isDefault is not None:
            if payload.isDefault and not template.isDefault:
                await self._templates.clear_owner_default(template.ownerUsername)
            template.isDefault = payload.isDefault

        await self._db.commit()
        await self._db.refresh(template)
        return ShiftTemplateResponse.model_validate(template)

    async def delete_template(self, template_id: int) -> None:
        template = await self._templates.get_by_id(template_id)
        if template is None:
            raise HTTPException(status_code=404, detail="Шаблон не найден")
        await self._ensure_owner_access(template)
        await self._templates.delete(template)
        await self._db.commit()

    async def apply_template(
        self, template_id: int, payload: ShiftTemplateApplyRequest
    ) -> int:
        template = await self._templates.get_by_id(template_id)
        if template is None:
            raise HTTPException(status_code=404, detail="Шаблон не найден")
        await self._ensure_owner_access(template)

        try:
            monday = datetime.strptime(payload.weekStart, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status_code=400, detail="Неверный формат weekStart")
        if monday.weekday() != 0:
            raise HTTPException(status_code=400, detail="weekStart должен быть понедельником")

        target_user_id = payload.targetUserId
        if target_user_id is None:
            target_user_id = self._current_user.id
        elif target_user_id != self._current_user.id and not self._is_admin():
            raise HTTPException(status_code=403, detail="Можно применять только к себе")

        created = 0
        for raw_slot in template.slots:
            slot = ShiftTemplateSlot.model_validate(raw_slot)
            shift_date = monday + timedelta(days=slot.weekday - 1)
            date_str = shift_date.strftime("%Y-%m-%d")
            req = ShiftRequest(
                userId=target_user_id,
                date=date_str,
                startTime=slot.startTime,
                endTime=slot.endTime,
            )
            try:
                await self._shifts_service.create_shift(
                    req, self._current_user.username, self._is_admin()
                )
                created += 1
            except ValueError as e:
                raise HTTPException(status_code=404, detail=str(e))
            except PermissionError as e:
                raise HTTPException(status_code=403, detail=str(e))

        return created
