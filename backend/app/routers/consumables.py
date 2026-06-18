import io
from datetime import datetime

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from core.limiter import limiter
from db.session import get_db
from models import User
from schemas import (
    ConsumableRequest,
    ConsumableResponse,
    InventoryForecastResponse,
    RefillRequest,
    ServiceConsumableRequest,
    ServiceConsumableResponse,
)
from services.auth_service import check_roles
from services.consumables_service import ConsumableNotFoundError, ConsumablesService

router = APIRouter(
    prefix="/api/consumables",
    tags=["consumables"],
)


@router.get("/", response_model=list[ConsumableResponse])
@limiter.limit("60/minute")
async def get_all_consumables(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin", "washer"])),
):
    svc = ConsumablesService(db)
    return await svc.get_all_consumables()


@router.get("/by-service/{service_id}", response_model=list[ServiceConsumableResponse])
@limiter.limit("60/minute")
async def get_consumables_by_service(
    request: Request,
    service_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin", "washer"])),
):
    svc = ConsumablesService(db)
    return await svc.get_consumables_by_service(service_id)


@router.post("/", response_model=ConsumableResponse)
@limiter.limit("10/minute")
async def create_consumable(
    request: Request,
    req: ConsumableRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    svc = ConsumablesService(db)
    return await svc.create_consumable(req)


@router.get("/alerts/low-stock", response_model=list[ConsumableResponse])
@limiter.limit("60/minute")
async def get_low_stock_alerts(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin", "washer"])),
):
    svc = ConsumablesService(db)
    return await svc.get_low_stock_alerts()


@router.get("/forecast", response_model=InventoryForecastResponse)
@limiter.limit("60/minute")
async def get_inventory_forecast(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin", "washer"])),
):
    svc = ConsumablesService(db)
    return await svc.get_inventory_forecast()


@router.get("/export")
@limiter.limit("10/minute")
async def export_consumables(
    request: Request,
    date_from: str = None,
    date_to: str = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin", "washer"])),
):
    """Экспорт отчёта по расходникам в Excel."""
    svc = ConsumablesService(db)
    try:
        data = await svc.export_consumables(date_from, date_to)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except RuntimeError:
        raise HTTPException(500, "Internal server error")

    filename = f"consumables_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"
    return StreamingResponse(
        io.BytesIO(data),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


@router.get("/import-template")
@limiter.limit("10/minute")
async def download_import_template(
    request: Request, current_user: User = Depends(check_roles(["admin", "washer"]))
):
    """Скачать пустой шаблон Excel для импорта пополнений."""
    svc = ConsumablesService(db=None)  # no DB needed
    try:
        data = await svc.generate_import_template()
    except RuntimeError:
        raise HTTPException(500, "Internal server error")

    return StreamingResponse(
        io.BytesIO(data),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": (
                "attachment; filename=consumables_import_template.xlsx"
            )
        },
    )


MAX_IMPORT_FILE_SIZE = 5 * 1024 * 1024  # 5 MB


@router.post("/import-refills")
@limiter.limit("10/minute")
async def import_refills(
    request: Request,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    """Массовый импорт пополнений из Excel. Ожидаются колонки: name, amount"""
    content_length = request.headers.get("content-length")
    if content_length and int(content_length) > MAX_IMPORT_FILE_SIZE:
        raise HTTPException(413, "Файл слишком большой. Максимум 5 МБ")

    content = await file.read()
    if len(content) > MAX_IMPORT_FILE_SIZE:
        raise HTTPException(413, "Файл слишком большой. Максимум 5 МБ")

    svc = ConsumablesService(db)
    try:
        return await svc.import_refills(content, current_user.username)
    except ValueError as e:
        raise HTTPException(400, str(e))
    except RuntimeError:
        raise HTTPException(500, "Internal server error")


# ========== Динамические пути ==========


@router.get("/{consumable_id}", response_model=ConsumableResponse)
@limiter.limit("60/minute")
async def get_consumable(
    request: Request,
    consumable_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin", "washer"])),
):
    svc = ConsumablesService(db)
    consumable = await svc.get_consumable(consumable_id)
    if not consumable:
        raise HTTPException(404, "Расходник не найден")
    return consumable


@router.put("/{consumable_id}", response_model=ConsumableResponse)
@limiter.limit("10/minute")
async def update_consumable(
    request: Request,
    consumable_id: str,
    req: ConsumableRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    svc = ConsumablesService(db)
    consumable = await svc.update_consumable(consumable_id, req)
    if not consumable:
        raise HTTPException(404, "Расходник не найден")
    return consumable


@router.delete("/{consumable_id}")
@limiter.limit("10/minute")
async def delete_consumable(
    request: Request,
    consumable_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    svc = ConsumablesService(db)
    deleted = await svc.delete_consumable(consumable_id)
    if not deleted:
        raise HTTPException(404, "Расходник не найден")
    return {"ok": True}


@router.post("/{consumable_id}/refill", response_model=ConsumableResponse)
@limiter.limit("10/minute")
async def refill_consumable(
    request: Request,
    consumable_id: str,
    req: RefillRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin", "washer"])),
):
    svc = ConsumablesService(db)
    consumable = await svc.refill_consumable(consumable_id, req, current_user.username)
    if not consumable:
        raise HTTPException(404, "Расходник не найден")
    return consumable


@router.get("/{consumable_id}/refill-history")
@limiter.limit("60/minute")
async def get_refill_history(
    request: Request,
    consumable_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin", "washer"])),
):
    svc = ConsumablesService(db)
    return await svc.get_refill_history(consumable_id)


@router.get("/{consumable_id}/forecast")
@limiter.limit("60/minute")
async def get_consumable_forecast(
    request: Request,
    consumable_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin", "washer"])),
):
    svc = ConsumablesService(db)
    result = await svc.get_consumable_forecast(consumable_id)
    if result is None:
        raise HTTPException(404, "Расходник не найден")
    return result


@router.post("/service-link", response_model=ServiceConsumableResponse)
@limiter.limit("10/minute")
async def link_consumable_to_service(
    request: Request,
    req: ServiceConsumableRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    svc = ConsumablesService(db)
    try:
        return await svc.link_consumable_to_service(req)
    except ConsumableNotFoundError as e:
        raise HTTPException(404, str(e))


@router.delete("/service-link/{service_id}/{consumable_id}")
@limiter.limit("10/minute")
async def unlink_consumable_from_service(
    request: Request,
    service_id: str,
    consumable_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
    svc = ConsumablesService(db)
    unlinked = await svc.unlink_consumable_from_service(service_id, consumable_id)
    if not unlinked:
        raise HTTPException(404, "Связь расходника и услуги не найдена")
    return {"ok": True}
