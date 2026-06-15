from typing import List

from core.limiter import limiter
from database import get_db
from db_models import User
from fastapi import APIRouter, Depends, Request
from models import (
    ShiftTemplateApplyRequest,
    ShiftTemplateCreateRequest,
    ShiftTemplateResponse,
    ShiftTemplateUpdateRequest,
)
from services.auth_service import check_roles, get_current_user
from services.shift_templates_service import ShiftTemplatesService
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/api/shift-templates", tags=["shift-templates"])


def _service(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return ShiftTemplatesService(db, current_user)


@router.get("/", response_model=List[ShiftTemplateResponse])
@limiter.limit("60/minute")
async def list_templates(
    request: Request,
    service: ShiftTemplatesService = Depends(_service),
):
    return await service.list_templates()


@router.post("/", response_model=ShiftTemplateResponse, status_code=201)
@limiter.limit("20/minute")
async def create_template(
    request: Request,
    payload: ShiftTemplateCreateRequest,
    service: ShiftTemplatesService = Depends(_service),
):
    return await service.create_template(payload)


@router.put("/{template_id}", response_model=ShiftTemplateResponse)
@limiter.limit("20/minute")
async def update_template(
    request: Request,
    template_id: int,
    payload: ShiftTemplateUpdateRequest,
    service: ShiftTemplatesService = Depends(_service),
):
    return await service.update_template(template_id, payload)


@router.delete("/{template_id}", status_code=204)
@limiter.limit("20/minute")
async def delete_template(
    request: Request,
    template_id: int,
    service: ShiftTemplatesService = Depends(_service),
):
    await service.delete_template(template_id)


@router.post("/{template_id}/apply")
@limiter.limit("10/minute")
async def apply_template(
    request: Request,
    template_id: int,
    payload: ShiftTemplateApplyRequest,
    service: ShiftTemplatesService = Depends(_service),
):
    count = await service.apply_template(template_id, payload)
    return {"applied": count}
