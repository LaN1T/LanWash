import json
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, func, insert
from sqlalchemy.exc import NoResultFound
from database import get_db
from models import AppointmentRequest, AppointmentResponse, AssignWasherRequest
from db_models import Appointment, DeletedNotification, Service, ServiceConsumable, ConsumableUsageLog
from datetime import datetime

router = APIRouter(prefix="/api/appointments", tags=["appointments"])

@router.get("/", response_model=list[AppointmentResponse])
async def get_all(db: AsyncSession = Depends(get_db)):
    from sqlalchemy import or_
    result = await db.execute(
        select(Appointment)
        .where(or_(Appointment.isHiddenFromAdmin == False, Appointment.isHiddenFromAdmin == None))
        .order_by(Appointment.dateTime.asc())
    )
    return result.scalars().all()

@router.get("/by-owner/{username}", response_model=list[AppointmentResponse])
async def get_by_owner(username: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Appointment).where(Appointment.ownerUsername == username.lower()).order_by(Appointment.dateTime.asc()))
    return result.scalars().all()

@router.get("/by-washer/{username}", response_model=list[AppointmentResponse])
async def get_by_washer(username: str, db: AsyncSession = Depends(get_db)):
    # PostgreSQL supports JSONB or string operations. 
    # For simple string array in JSON, we use LIKE for compatibility.
    result = await db.execute(
        select(Appointment).where(Appointment.assignedWasher.like(f'%"{username.lower()}"%')).order_by(Appointment.dateTime.asc())
    )
    return result.scalars().all()

@router.post("/", response_model=AppointmentResponse)
async def create(req: AppointmentRequest, db: AsyncSession = Depends(get_db)):
    appt = Appointment(
        id=req.id,
        clientName=req.clientName,
        carModel=req.carModel,
        carNumber=req.carNumber,
        dateTime=req.dateTime,
        washType=req.washType,
        additionalServices=req.additionalServices,
        status=req.status,
        notes=req.notes,
        isFavorite=int(req.isFavorite),
        ownerUsername=req.ownerUsername,
        promoPrice=req.promoPrice,
        paidPrice=req.paidPrice,
        isModifiedByAdmin=int(req.isModifiedByAdmin),
        originalPrice=req.originalPrice,
        assignedWasher=req.assignedWasher,
        promoName=req.promoName
    )
    db.add(appt)
    await db.commit()

    if req.status == "completed":
        await _track_consumables_usage(db, req.id, req.washType, req.additionalServices)
        await db.commit() # Commit again after tracking consumables

    await db.refresh(appt)
    return appt

async def _track_consumables_usage(db: AsyncSession, appt_id: str, wash_type: str, additional_services):
    import json
    if isinstance(additional_services, str):
        try:
            additional_services = json.loads(additional_services)
        except:
            additional_services = []
    
    print(f"DEBUG: Tracking usage for {appt_id}, wash_type: {wash_type}, services: {additional_services}")
    all_service_ids = set()
    
    # Map wash_type to ID
    wash_map = {'express': 's3', 'basic': 's1', 'complex': 's2', 'premium': 's21'}
    if wash_type.strip().lower() in wash_map:
        all_service_ids.add(wash_map[wash_type.strip().lower()])

    # Получаем мапу имя -> id для старых записей
    from db_models import Service
    svc_res = await db.execute(select(Service.id, Service.name))
    svc_rows = svc_res.all()
    name_to_id = {s.name.strip().lower(): s.id for s in svc_rows}
    id_to_id = {s.id: s.id for s in svc_rows}

    # Добавляем все ID услуг из списка
    for s_item in additional_services:
        # Проверяем, это ID или имя
        if s_item in id_to_id:
            all_service_ids.add(s_item)
        elif s_item.strip().lower() in name_to_id:
            all_service_ids.add(name_to_id[s_item.strip().lower()])
        else:
            all_service_ids.add(s_item) # Оставляем как есть, вдруг это новый ID

    print(f"DEBUG: Final service IDs to track: {all_service_ids}")

    # Find promo via Appointment.promoName
    result_appt = await db.execute(select(Appointment.promoName).where(Appointment.id == appt_id))
    promo_name = result_appt.scalar_one_or_none()
    print(f"DEBUG: Promo name found: {promo_name}")
    
    if promo_name:
        from db_models import Promo
        res_promo = await db.execute(select(Promo).where(Promo.name == promo_name))
        promo = res_promo.scalar_one_or_none()
        if promo:
            all_service_ids.add(promo.serviceId)

    # Accumulate consumable usage
    from collections import defaultdict
    consumable_totals = defaultdict(float)
    
    for s_id in all_service_ids:
        # Важно: используем фильтр по атрибуту serviceId объекта ServiceConsumable
        result = await db.execute(select(ServiceConsumable).where(ServiceConsumable.serviceId == s_id))
        consumables = result.scalars().all()
        print(f"DEBUG: Found {len(consumables)} consumables for service {s_id}")
        for c in consumables:
            if c.consumableId == "c_vac":
                consumable_totals["c_vac"] = 1.0
            else:
                consumable_totals[c.consumableId] += c.quantity_per_service
    print(f"DEBUG: Consumable totals: {dict(consumable_totals)}")

    # Write logs
    for c_id, qty in consumable_totals.items():
        db.add(ConsumableUsageLog(
            appointmentId=appt_id,
            consumableId=c_id,
            quantityUsed=qty,
            timestamp=datetime.now().isoformat()
        ))

@router.put("/{appt_id}", response_model=AppointmentResponse)
async def update_appt(appt_id: str, req: AppointmentRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Appointment).where(Appointment.id == appt_id))
    appt = result.scalar_one_or_none()
    if not appt:
        raise HTTPException(404, "Запись не найдена")
    
    old_status = appt.status
    
    appt.clientName = req.clientName
    appt.carModel = req.carModel
    appt.carNumber = req.carNumber
    appt.dateTime = req.dateTime
    appt.washType = req.washType
    appt.additionalServices = req.additionalServices
    appt.status = req.status
    appt.notes = req.notes
    appt.isFavorite = int(req.isFavorite)
    appt.ownerUsername = req.ownerUsername
    appt.promoPrice = req.promoPrice
    appt.paidPrice = req.paidPrice
    appt.isModifiedByAdmin = int(req.isModifiedByAdmin)
    appt.originalPrice = req.originalPrice
    appt.assignedWasher = req.assignedWasher
    appt.promoName = req.promoName
    
    await db.commit()
    
    if req.status == "completed":
        await _track_consumables_usage(db, appt_id, req.washType, req.additionalServices)
        await db.commit()
        
    await db.refresh(appt)
    return appt

@router.delete("/{appt_id}")
async def delete_appt(appt_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Appointment.ownerUsername).where(Appointment.id == appt_id))
    owner = result.scalar_one_or_none()
    
    if owner:
        db.add(DeletedNotification(username=owner, createdAt=datetime.now().isoformat()))
        
    await db.execute(update(Appointment).where(Appointment.id == appt_id).values(isHiddenFromAdmin=True))
    await db.commit()
    return {"ok": True}

@router.post("/{appt_id}/toggle-favorite")
async def toggle_favorite(appt_id: str, db: AsyncSession = Depends(get_db)):
    await db.execute(update(Appointment).where(Appointment.id == appt_id).values(isFavorite=1 - Appointment.isFavorite))
    await db.commit()
    return {"ok": True}

@router.post("/{appt_id}/assign-washer")
async def assign_washer(appt_id: str, req: AssignWasherRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Appointment).where(Appointment.id == appt_id))
    appt = result.scalar_one_or_none()
    if not appt:
        raise HTTPException(404, "Запись не найдена")

    try:
        current = json.loads(appt.assignedWasher) if appt.assignedWasher else []
    except:
        current = []

    username = req.washerUsername.lower()
    if username in current:
        current.remove(username)
    else:
        if len(current) >= 3:
            raise HTTPException(400, "Максимум 3 мойщика")
        current.append(username)

    appt.assignedWasher = json.dumps(current)
    await db.commit()
    await db.refresh(appt)
    return appt

@router.get("/deleted-notification/{username}")
async def get_deleted_notification(username: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(func.count(DeletedNotification.id)).where(DeletedNotification.username == username.lower()))
    count = result.scalar()
    return {"hasNotification": count > 0}

@router.delete("/deleted-notification/{username}")
async def clear_deleted_notification(username: str, db: AsyncSession = Depends(get_db)):
    await db.execute(delete(DeletedNotification).where(DeletedNotification.username == username.lower()))
    await db.commit()
    return {"ok": True}

@router.post("/{appt_id}/clear-admin-flag")
async def clear_admin_flag(appt_id: str, db: AsyncSession = Depends(get_db)):
    await db.execute(update(Appointment).where(Appointment.id == appt_id).values(isModifiedByAdmin=0))
    await db.commit()
    return {"ok": True}

@router.get("/stats")
async def stats(db: AsyncSession = Depends(get_db)):
    res_total = await db.execute(select(func.count(Appointment.id)))
    res_sched = await db.execute(select(func.count(Appointment.id)).where(Appointment.status == 'scheduled'))
    res_comp = await db.execute(select(func.count(Appointment.id)).where(Appointment.status == 'completed'))
    return {
        "total": res_total.scalar(), 
        "scheduled": res_sched.scalar(), 
        "completed": res_comp.scalar()
    }
