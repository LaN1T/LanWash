import json
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, func, or_
from database import get_db
from models import AppointmentRequest, AppointmentResponse, AssignWasherRequest
from db_models import (
    Appointment, DeletedNotification, Service, ServiceConsumable, FcmToken,
    ConsumableUsageLog, WashTypeConsumable, Promo, PromoIncludedExtra,
    WashTypeIncludedExtra,
)
from datetime import datetime
from collections import defaultdict
from services.fcm_service import fcm_service

router = APIRouter(prefix="/api/appointments", tags=["appointments"])

@router.get("/", response_model=list[AppointmentResponse])
async def get_all(db: AsyncSession = Depends(get_db)):
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
    # JSON-массив в строке. Используем LIKE по точному токену "username"
    result = await db.execute(
        select(Appointment)
        .where(Appointment.assignedWasher.like(f'%"{username.lower()}"%'))
        .order_by(Appointment.dateTime.asc())
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
        washTypeId=req.washTypeId,
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
        promoId=req.promoId,
    )
    db.add(appt)
    await db.commit()

    if req.status == "completed":
        await _track_consumables_usage(db, req.id, req.washTypeId, req.additionalServices, req.promoId)
        await db.commit()

    # Отправка уведомления клиенту о новой записи
    if appt.ownerUsername:
        res = await db.execute(select(FcmToken.token).where(FcmToken.username == appt.ownerUsername))
        tokens = res.scalars().all()
        if tokens:
            await fcm_service.send_notification_to_tokens(
                tokens,
                title="Новая запись создана!",
                body=f"Ваша запись на мойку {appt.carModel} в {appt.dateTime} успешно создана."
            )

    await db.refresh(appt)
    return appt


async def _track_consumables_usage(db: AsyncSession, appt_id: str, wash_type_id: str, additional_services, promo_id: str | None):
    """Списание расходников: по типу мойки + по каждой доп.услуге (по id)."""
    if isinstance(additional_services, str):
        try:
            additional_services = json.loads(additional_services)
        except Exception:
            additional_services = []

    extra_ids = set(additional_services or [])

    # Доп. услуги акции тоже учитываются
    if promo_id:
        res_promo_extras = await db.execute(
            select(PromoIncludedExtra.extraServiceId)
            .where(PromoIncludedExtra.promoId == promo_id)
        )
        for (eid,) in res_promo_extras.all():
            extra_ids.add(eid)

    # Включённые в тип мойки доп.услуги тоже учитываются
    res_wt_extras = await db.execute(
        select(WashTypeIncludedExtra.extraServiceId)
        .where(WashTypeIncludedExtra.washTypeId == wash_type_id)
    )
    for (eid,) in res_wt_extras.all():
        extra_ids.add(eid)

    consumable_totals: dict[str, float] = defaultdict(float)

    # Расходники типа мойки
    res_wt_cons = await db.execute(
        select(WashTypeConsumable.consumableId, WashTypeConsumable.quantity_per_service)
        .where(WashTypeConsumable.washTypeId == wash_type_id)
    )
    for c_id, qty in res_wt_cons.all():
        consumable_totals[c_id] += float(qty)

    # Расходники доп.услуг
    if extra_ids:
        res_sc = await db.execute(
            select(ServiceConsumable.consumableId, ServiceConsumable.quantity_per_service, ServiceConsumable.serviceId)
            .where(ServiceConsumable.serviceId.in_(extra_ids))
        )
        for c_id, qty, _s_id in res_sc.all():
            if c_id == "c_vac":
                # Пылесос — один ресурс за запись
                consumable_totals[c_id] = max(consumable_totals[c_id], 1.0)
            else:
                consumable_totals[c_id] += float(qty)

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

    # Сохраняем старые значения для сравнения
    old_status = appt.status
    old_datetime = appt.dateTime
    old_assigned_washer = appt.assignedWasher

    appt.clientName = req.clientName
    appt.carModel = req.carModel
    appt.carNumber = req.carNumber
    appt.dateTime = req.dateTime
    appt.washTypeId = req.washTypeId
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
    appt.promoId = req.promoId

    await db.commit()

    if req.status == "completed":
        # Удаляем предыдущие записи расхода перед пересчётом
        await db.execute(delete(ConsumableUsageLog).where(ConsumableUsageLog.appointmentId == appt_id))
        await _track_consumables_usage(db, appt_id, req.washTypeId, req.additionalServices, req.promoId)
        await db.commit()

    # Логика отправки уведомлений
    if appt.ownerUsername:
        tokens_res = await db.execute(select(FcmToken.token).where(FcmToken.username == appt.ownerUsername))
        client_tokens = tokens_res.scalars().all()

        if client_tokens:
            if old_status != appt.status:
                await fcm_service.send_notification_to_tokens(
                    client_tokens,
                    title="Изменение статуса записи",
                    body=f"Ваша запись на мойку {appt.carModel} в {appt.dateTime} теперь имеет статус: {appt.status}."
                )
            elif old_datetime != appt.dateTime:
                await fcm_service.send_notification_to_tokens(
                    client_tokens,
                    title="Время записи изменено",
                    body=f"Ваша запись на мойку {appt.carModel} перенесена на: {appt.dateTime}."
                )
            # Можно добавить другие проверки на изменения (цены, услуг и т.д.)

    # Уведомление мойщикам при назначении
    new_assigned_washers = json.loads(appt.assignedWasher) if appt.assignedWasher else []
    old_assigned_washers = json.loads(old_assigned_washer) if old_assigned_washer else []

    added_washers = [w for w in new_assigned_washers if w not in old_assigned_washers]
    removed_washers = [w for w in old_assigned_washers if w not in new_assigned_washers]

    for washer_username in added_washers:
        tokens_res = await db.execute(select(FcmToken.token).where(FcmToken.username == washer_username))
        washer_tokens = tokens_res.scalars().all()
        if washer_tokens:
            await fcm_service.send_notification_to_tokens(
                washer_tokens,
                title="Назначена новая запись",
                body=f"Вы назначены на мойку {appt.carModel} в {appt.dateTime}."
            )
    for washer_username in removed_washers:
        tokens_res = await db.execute(select(FcmToken.token).where(FcmToken.username == washer_username))
        washer_tokens = tokens_res.scalars().all()
        if washer_tokens:
            await fcm_service.send_notification_to_tokens(
                washer_tokens,
                title="Назначение отменено",
                body=f"Вы были удалены из записи на мойку {appt.carModel} в {appt.dateTime}."
            )

    await db.refresh(appt)
    return appt

@router.delete("/{appt_id}")
async def delete_appt(appt_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Appointment.ownerUsername, Appointment.carModel, Appointment.dateTime).where(Appointment.id == appt_id))
    appt_info = result.first()

    if appt_info:
        owner = appt_info.ownerUsername
        car_model = appt_info.carModel
        date_time = appt_info.dateTime
        db.add(DeletedNotification(username=owner, createdAt=datetime.now().isoformat()))

        # Отправка уведомления клиенту об удалении записи
        tokens_res = await db.execute(select(FcmToken.token).where(FcmToken.username == owner))
        client_tokens = tokens_res.scalars().all()
        if client_tokens:
            await fcm_service.send_notification_to_tokens(
                client_tokens,
                title="Запись отменена",
                body=f"Ваша запись на мойку {car_model} в {date_time} была отменена."
            )

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
    except Exception:
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
