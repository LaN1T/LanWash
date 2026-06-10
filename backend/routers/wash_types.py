from fastapi import APIRouter, HTTPException, Depends, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from core.limiter import limiter
from database import get_db
from db_models import User
from models import WashTypeRequest, WashTypeResponse
from services.auth_service import get_current_user, check_roles
from services.wash_types_service import WashTypesService

router = APIRouter(
    prefix="/api/wash-types",
    tags=["wash-types"],
)


def _to_response(wt, extras_map: dict[str, list[str]]) -> dict:
    return {
        "id": wt.id,
        "code": wt.code,
        "name": wt.name,
        "description": wt.description,
        "basePrice": wt.basePrice,
        "durationMinutes": wt.durationMinutes,
        "sortOrder": wt.sortOrder,
        "includedExtraIds": extras_map.get(wt.id, []),
    }


async def _to_response_single(svc: WashTypesService, wt) -> dict:
    included = await svc.get_included_extra_ids(wt.id)
    return {
        "id": wt.id,
        "code": wt.code,
        "name": wt.name,
        "description": wt.description,
        "basePrice": wt.basePrice,
        "durationMinutes": wt.durationMinutes,
        "sortOrder": wt.sortOrder,
        "includedExtraIds": included,
    }


@router.get("/", response_model=list[WashTypeResponse])
@limiter.limit("60/minute")
async def get_all(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = WashTypesService(db)
    wash_types = await svc.get_all()
    if not wash_types:
        return []
    extras_map = await svc.get_extras_map([wt.id for wt in wash_types])
    return [_to_response(wt, extras_map) for wt in wash_types]


@router.get("/{wash_type_id}", response_model=WashTypeResponse)
@limiter.limit("60/minute")
async def get_one(
    request: Request,
    wash_type_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    svc = WashTypesService(db)
    wt = await svc.get_one(wash_type_id)
    if not wt:
        raise HTTPException(404, "Тип мойки не найден")
    return await _to_response_single(svc, wt)


@router.put("/{wash_type_id}", response_model=WashTypeResponse)
@limiter.limit("10/minute")
async def update(
    request: Request,
    wash_type_id: str,
    req: WashTypeRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    svc = WashTypesService(db)
    wt = await svc.update(wash_type_id, req)
    if not wt:
        raise HTTPException(404, "Тип мойки не найден")
    return await _to_response_single(svc, wt)
