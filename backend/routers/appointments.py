import json
from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, func, or_
from database import get_db
from models import AppointmentRequest, AppointmentResponse, AssignWasherRequest
from db_models import (
    Appointment, DeletedNotification, Service, ServiceConsumable, FcmToken,
    ConsumableUsageLog, WashTypeConsumable, Promo, PromoIncludedExtra,
    WashTypeIncludedExtra, User,
)
from datetime import datetime
from collections import defaultdict
from services.fcm_service import fcm_service
from services.workload_service import workload_service
from services.auth_service import get_current_user, check_roles
from core.security import decrypt_token

router = APIRouter(prefix="/api/appointments", tags=["appointments"])

@router.get("/busy-slots", response_model=dict)
async def get_busy_slots(date: str, db: AsyncSession = Depends(get_db)):
    """date: YYYY-MM-DD"""
    return await workload_service.get_busy_slots(db, date)

@router.get("/last-updated", response_model=dict)
async def get_last_updated(db: AsyncSession = Depends(get_db)):
    # Lightweight check: count of appointments and max ID as a proxy for 'has changed'
    res = await db.execute(select(func.count(Appointment.id), func.max(Appointment.id)))
    count, max_id = res.one()
    return {"count": count, "max_id": max_id}

@router.get("/", response_model=list[AppointmentResponse])
async def get_all(
    page: int = 1,
    limit: int = 6,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # P0: IDOR check for get_all - allow admin to see all, others only non-hidden
    offset = (page - 1) * limit
    if current_user.role == 'admin':
        result = await db.execute(
            select(Appointment)
            .order_by(Appointment.dateTime.asc())
            .offset(offset)
            .limit(limit)
        )
    else:
        result = await db.execute(
            select(Appointment)
            .where(or_(Appointment.isHiddenFromAdmin == False, Appointment.isHiddenFromAdmin == None))
            .order_by(Appointment.dateTime.asc())
            .offset(offset)
            .limit(limit)
        )
    return result.scalars().all()

@router.get("/by-owner/{username}", response_model=list[AppointmentResponse])
async def get_by_owner(username: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # P0: IDOR check - only owner or admin can view.
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к записям этого пользователя.")
    result = await db.execute(select(Appointment).where(Appointment.ownerUsername == username.lower()).order_by(Appointment.dateTime.asc()))
    return result.scalars().all()

@router.get("/by-washer/{username}", response_model=list[AppointmentResponse])
async def get_by_washer(username: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # P0: IDOR check - only washer or admin can view.
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к записям этого мойщика.")
    # JSON-массив в строке. Используем LIKE по точному токену "username"
    result = await db.execute(
        select(Appointment)
        .where(Appointment.assignedWasher.like(f'%"{username.lower()}"%'))
        .order_by(Appointment.dateTime.asc())
    )
    return result.scalars().all()

async def _track_consumables_usage(db: AsyncSession, appt_id: str, wash_type_id: str, additional_services: list[str], promo_id: str = None):
    # 1. Сбор расходников из типа мойки
    res_wt = await db.execute(select(WashTypeConsumable.consumableId, WashTypeConsumable.quantity_per_service).where(WashTypeConsumable.washTypeId == wash_type_id))
    usage_map = {row[0]: float(row[1]) for row in res_wt.all()}

    # 2. Сбор расходников из промо
    if promo_id:
        res_promo = await db.execute(select(PromoIncludedExtra.extraServiceId).where(PromoIncludedExtra.promoId == promo_id))
        # Здесь мы полагаем, что логика промо тоже требует расходников, 
        # но для простоты добавим только расходники самих доп.услуг ниже.
        pass

    # 3. Сбор расходников из доп.услуг
    if additional_services:
        try:
            # Если это JSON строка, парсим её
            service_ids = json.loads(additional_services) if isinstance(additional_services, str) else additional_services
        except:
            service_ids = additional_services if isinstance(additional_services, list) else []
            
        if service_ids:
            res_svc = await db.execute(select(ServiceConsumable.consumableId, ServiceConsumable.quantity_per_service).where(ServiceConsumable.serviceId.in_(service_ids)))
            for cid, qty in res_svc.all():
                usage_map[cid] = usage_map.get(cid, 0.0) + float(qty)

    # 4. Сохранение в лог
    for cid, qty in usage_map.items():
        db.add(ConsumableUsageLog(
            appointmentId=appt_id,
            consumableId=cid,
            quantityUsed=qty,
            timestamp=datetime.now().isoformat()
        ))

@router.post("/", response_model=AppointmentResponse)
async def create(req: AppointmentRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    owner_username = req.ownerUsername if req.ownerUsername else current_user.username
    
    if current_user.username != owner_username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Вы не можете создавать записи для других пользователей.")

    # Находим свободный бокс
    duration = await workload_service.get_appointment_duration(db, req.washTypeId, req.additionalServices, req.promoId)
    box_idx = await workload_service.find_available_box(db, req.dateTime, duration)
    
    if box_idx == -1:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "К сожалению, на это время нет свободных боксов.")

    appt_data = {
        "id": req.id,
        "clientName": req.clientName,
        "carModel": req.carModel,
        "carNumber": req.carNumber,
        "dateTime": req.dateTime,
        "washTypeId": req.washTypeId,
        "additionalServices": req.additionalServices,
        "status": req.status,
        "notes": req.notes,
        "isFavorite": int(req.isFavorite),
        "ownerUsername": owner_username.lower(),
        "promoPrice": req.promoPrice,
        "paidPrice": req.paidPrice,
        "promoId": req.promoId,
        "box_index": box_idx,
    }

    if current_user.role == 'admin':
        appt_data.update({
            "isModifiedByAdmin": int(req.isModifiedByAdmin),
            "isModifiedByWasher": int(req.isModifiedByWasher),
            "isSeenByClient": 1 if not (req.isModifiedByAdmin or req.isModifiedByWasher) else 0,
            "originalPrice": req.originalPrice,
            "assignedWasher": req.assignedWasher,
        })
    else:
        appt_data.update({
            "isModifiedByAdmin": 0,
            "isModifiedByWasher": 0,
            "isSeenByClient": 1,
            "originalPrice": req.paidPrice,
            "assignedWasher": "[]",
        })

    appt = Appointment(**appt_data)
    db.add(appt)
    await db.commit()

    if req.status == "completed":
        await _track_consumables_usage(db, req.id, req.washTypeId, req.additionalServices, req.promoId)
        await db.commit()

    if appt.ownerUsername:
        res = await db.execute(select(FcmToken.token).where(FcmToken.username == appt.ownerUsername))
        encrypted_tokens = res.scalars().all()
        if encrypted_tokens:
            tokens = [decrypt_token(t) for t in encrypted_tokens]
            await fcm_service.send_notification_to_tokens(
                tokens,
                title="Новая запись создана!",
                body=f"Ваша запись на мойку {appt.carModel} в {appt.dateTime} успешно создана."
            )

    await db.refresh(appt)
    return appt


from datetime import datetime

def format_date(dt_str):
    if not dt_str:
        return "неизвестное время"
    try:
        # Пытаемся распарсить, если это строка ISO
        if isinstance(dt_str, str):
            dt = datetime.fromisoformat(dt_str.replace('Z', '+00:00'))
        else:
            dt = dt_str
        return dt.strftime("%d.%m %H:%M")
    except:
        return str(dt_str)


@router.put("/{appt_id}", response_model=AppointmentResponse)
async def update_appt(appt_id: str, req: AppointmentRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    result = await db.execute(select(Appointment).where(Appointment.id == appt_id))
    appt = result.scalar_one_or_none()
    if not appt:
        raise HTTPException(404, "Запись не найдена")

    # Store original values for comparison to detect actual admin changes
    original_clientName = appt.clientName
    original_carModel = appt.carModel
    original_carNumber = appt.carNumber
    original_dateTime = appt.dateTime
    original_washTypeId = appt.washTypeId
    original_additionalServices = appt.additionalServices
    original_status = appt.status
    original_notes = appt.notes
    original_isFavorite = appt.isFavorite
    original_ownerUsername = appt.ownerUsername
    original_promoPrice = appt.promoPrice
    original_paidPrice = appt.paidPrice
    original_originalPrice = appt.originalPrice
    original_assignedWasher = appt.assignedWasher
    original_promoId = appt.promoId
    original_box_index = appt.box_index
    
    # Логирование для отладки прав доступа
    print(f"DEBUG: Updating appointment {appt_id} by {current_user.username} (role: {current_user.role})")
    print(f"DEBUG: Appointment owner: {appt.ownerUsername}")

    # Разрешаем владельцу, админу или мойщику редактировать запись
    # Проверяем, является ли текущий пользователь владельцем, админом или мойщиком
    is_owner = current_user.username == appt.ownerUsername
    is_admin = current_user.role == 'admin'
    is_washer = current_user.role == 'washer'
    
    if not (is_owner or is_admin or is_washer):
        print(f"DEBUG: Access denied. (is_owner={is_owner}, is_admin={is_admin}, is_washer={is_washer})")
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет прав на редактирование этой записи.")

    old_status = appt.status
    old_datetime = appt.dateTime
    old_assigned_washer = appt.assignedWasher

    # Проверка доступности бокса, если время или услуги изменились
    duration = await workload_service.get_appointment_duration(db, req.washTypeId, req.additionalServices, req.promoId)
    box_idx = await workload_service.find_available_box(db, req.dateTime, duration, exclude_appt_id=appt_id)
    
    if box_idx == -1:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "К сожалению, на это время нет свободных боксов.")

    appt.clientName = req.clientName
    appt.carModel = req.carModel
    appt.carNumber = req.carNumber
    appt.dateTime = req.dateTime
    appt.washTypeId = req.washTypeId
    appt.additionalServices = req.additionalServices
    appt.status = req.status
    appt.notes = req.notes
    appt.isFavorite = int(req.isFavorite)
    appt.promoPrice = req.promoPrice
    appt.paidPrice = req.paidPrice
    appt.promoId = req.promoId
    appt.box_index = box_idx
    
    if current_user.role == 'admin':
        appt.ownerUsername = req.ownerUsername.lower()
        appt.originalPrice = req.originalPrice
        appt.assignedWasher = req.assignedWasher

        # Detect if admin made any changes that should trigger a client notification
        def normalize_json(s):
            try:
                return sorted(json.loads(s)) if isinstance(json.loads(s), list) else json.loads(s)
            except:
                return s

        admin_made_changes = False
        if appt.clientName != original_clientName: admin_made_changes = True
        if appt.carModel != original_carModel: admin_made_changes = True
        if appt.carNumber != original_carNumber: admin_made_changes = True
        if appt.dateTime != original_dateTime: admin_made_changes = True
        if appt.washTypeId != original_washTypeId: admin_made_changes = True
        if normalize_json(appt.additionalServices) != normalize_json(original_additionalServices): admin_made_changes = True
        if appt.status != original_status: admin_made_changes = True
        if appt.notes != original_notes: admin_made_changes = True
        if appt.isFavorite != original_isFavorite: admin_made_changes = True
        if appt.ownerUsername != original_ownerUsername: admin_made_changes = True
        if appt.promoPrice != original_promoPrice: admin_made_changes = True
        if appt.paidPrice != original_paidPrice: admin_made_changes = True
        if appt.originalPrice != original_originalPrice: admin_made_changes = True
        if normalize_json(appt.assignedWasher) != normalize_json(original_assignedWasher): admin_made_changes = True
        if appt.promoId != original_promoId: admin_made_changes = True
        if appt.box_index != original_box_index: admin_made_changes = True

        if admin_made_changes:
            print(f"Admin made real changes to appointment {appt.id}, triggering notification.")
            appt.isModifiedByAdmin = 1
            appt.isSeenByClient = 0
        # If no changes, the flags (isModifiedByAdmin, isSeenByClient) remain as they were

    elif current_user.role == 'washer':
        # Если статус изменился, помечаем, что это изменение от мойщика
        if old_status != req.status:
            appt.isModifiedByWasher = 1
            appt.isSeenByClient = 0
    
    await db.commit()

    if req.status == "completed":
        await db.execute(delete(ConsumableUsageLog).where(ConsumableUsageLog.appointmentId == appt_id))
        await _track_consumables_usage(db, appt_id, req.washTypeId, req.additionalServices, req.promoId)
        await db.commit()

    if appt.ownerUsername:
        tokens_res = await db.execute(select(FcmToken.token).where(FcmToken.username == appt.ownerUsername))
        encrypted_tokens = tokens_res.scalars().all()
        
        if encrypted_tokens:
            client_tokens = [decrypt_token(t) for t in encrypted_tokens]
            
            # Всегда уведомляем, если что-то изменилось, чтобы клиент обновил данные
            title, body = "Обновление записи", "Ваша запись была обновлена."
            if old_status != appt.status:
                dt_str = format_date(appt.dateTime)
                if appt.status == "completed":
                    title, body = "Запись завершена", "Ваша запись завершена. Спасибо, что выбрали нас!"
                elif appt.status == "in_progress":
                    title, body = "Начало обслуживания", f"Ваш авто в боксе {appt.box_index + 1}. Мы начали!"
                elif appt.status == "cancelled":
                    title, body = "Запись отменена", f"К сожалению, запись на {dt_str} была отменена."
                elif appt.status == "scheduled":
                    title, body = "Запись подтверждена", f"Вы записались на мойку {dt_str}. Бокс {appt.box_index + 1}."
            
            await fcm_service.send_notification_to_tokens(client_tokens, title=title, body=body, data={"type": "appointment_updated", "id": appt.id})

            if old_datetime != appt.dateTime:
                dt_str = format_date(appt.dateTime)
                await fcm_service.send_notification_to_tokens(
                    client_tokens,
                    title="Время мойки изменено",
                    body=f"Ваша запись перенесена на {dt_str}.",
                    data={"type": "appointment_updated", "id": appt.id}
                )

    new_assigned_washers = json.loads(appt.assignedWasher) if appt.assignedWasher else []
    old_assigned_washers = json.loads(old_assigned_washer) if old_assigned_washer else []

    added_washers = [w for w in new_assigned_washers if w not in old_assigned_washers]
    removed_washers = [w for w in old_assigned_washers if w not in new_assigned_washers]

    for washer_username in added_washers:
        tokens_res = await db.execute(select(FcmToken.token).where(FcmToken.username == washer_username))
        encrypted_tokens = tokens_res.scalars().all()
        if encrypted_tokens:
            tokens = [decrypt_token(t) for t in encrypted_tokens]
            dt_str = format_date(appt.dateTime)
            await fcm_service.send_notification_to_tokens(
                tokens,
                title="Новая запись",
                body=f"Вы назначены на мойку {appt.carModel} {dt_str}."
            )
    for washer_username in removed_washers:
        tokens_res = await db.execute(select(FcmToken.token).where(FcmToken.username == washer_username))
        encrypted_tokens = tokens_res.scalars().all()
        if encrypted_tokens:
            tokens = [decrypt_token(t) for t in encrypted_tokens]
            dt_str = format_date(appt.dateTime)
            await fcm_service.send_notification_to_tokens(
                tokens,
                title="Назначение отменено",
                body=f"Вы были удалены из записи на мойку {appt.carModel} {dt_str}."
            )

    await db.refresh(appt)
    return appt

@router.delete("/{appt_id}")
async def delete_appt(appt_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # P0: IDOR check - Only admin or the owner can delete.
    result = await db.execute(select(Appointment.ownerUsername, Appointment.carModel, Appointment.dateTime).where(Appointment.id == appt_id))
    appt_info = result.first()

    if not appt_info:
        raise HTTPException(404, "Запись не найдена")
    if current_user.username != appt_info.ownerUsername and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет прав на удаление этой записи.")

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
async def toggle_favorite(appt_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # P0: IDOR check - Only owner or admin can toggle favorite.
    result = await db.execute(select(Appointment.ownerUsername).where(Appointment.id == appt_id))
    owner_username = result.scalar_one_or_none()
    if not owner_username:
        raise HTTPException(404, "Запись не найдена")
    if current_user.username != owner_username and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет прав на изменение избранного для этой записи.")

    await db.execute(update(Appointment).where(Appointment.id == appt_id).values(isFavorite=1 - Appointment.isFavorite))
    await db.commit()
    return {"ok": True}

@router.post("/{appt_id}/assign-washer")
async def assign_washer(appt_id: str, req: AssignWasherRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    # Only admin can assign/unassign washers.
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
        # Проверяем, что пользователь существует и у него роль 'washer'
        user_res = await db.execute(select(User).where(User.username == username))
        target_user = user_res.scalar_one_or_none()
        if not target_user or target_user.role != 'washer':
            raise HTTPException(400, f"Пользователь {username} не является мойщиком")
            
        if len(current) >= 3:
            raise HTTPException(400, "Максимум 3 мойщика")
        current.append(username)

    appt.assignedWasher = json.dumps(current)
    await db.commit()
    await db.refresh(appt)

    # Уведомление мойщику при назначении или снятии
    tokens_res = await db.execute(select(FcmToken.token).where(FcmToken.username == username))
    encrypted_tokens = tokens_res.scalars().all()
    if encrypted_tokens:
        tokens = []
        for t in encrypted_tokens:
            try:
                decrypted = decrypt_token(t)
                tokens.append(decrypted)
            except Exception as e:
                print(f"DEBUG: Failed to decrypt token for {username}: {e}")
        
        if tokens:
            dt_str = format_date(appt.dateTime)
            if username in current:
                # Назначен
                box_str = f" Бокс №{appt.box_index + 1}" if appt.box_index is not None else ""
                await fcm_service.send_notification_to_tokens(
                    tokens,
                    title="Новая запись",
                    body=f"Вы назначены на мойку {appt.carModel} {dt_str}.{box_str}",
                    data={"type": "appointment_updated", "id": appt.id}
                )
                print(f"Assignment notification sent to washer {username}")
            else:
                # Снят
                await fcm_service.send_notification_to_tokens(
                    tokens,
                    title="Запись снята",
                    body=f"Вы были сняты с записи на мойку {appt.carModel} {dt_str}.",
                    data={"type": "appointment_updated", "id": appt.id}
                )
                print(f"Removal notification sent to washer {username}")

    return appt

@router.get("/deleted-notification/{username}")
async def get_deleted_notification(username: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # P0: IDOR check - Only the user themselves or admin can check.
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к этому уведомлению.")
    result = await db.execute(select(func.count(DeletedNotification.id)).where(DeletedNotification.username == username.lower()))
    count = result.scalar()
    return {"hasNotification": count > 0}

@router.delete("/deleted-notification/{username}")
async def clear_deleted_notification(username: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # P0: IDOR check - Only the user themselves or admin can clear.
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет прав на очистку этого уведомления.")
    await db.execute(delete(DeletedNotification).where(DeletedNotification.username == username.lower()))
    await db.commit()
    return {"ok": True}

@router.post("/{appt_id}/clear-admin-flag")
async def clear_admin_flag(appt_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # P0: IDOR check - Only admin or the owner can clear the flag.
    result = await db.execute(select(Appointment.ownerUsername).where(Appointment.id == appt_id))
    owner_username = result.scalar_one_or_none()
    if not owner_username:
        raise HTTPException(404, "Запись не найдена")
    if current_user.username != owner_username and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет прав на снятие флага модификации.")

    await db.execute(update(Appointment).where(Appointment.id == appt_id).values(
        isModifiedByAdmin=0,
        isModifiedByWasher=0,
        isSeenByClient=1
    ))
    await db.commit()
    return {"ok": True}

@router.post("/{appt_id}/mark-seen")
async def mark_appointment_seen(appt_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # P0: IDOR check - Only the owner or admin can mark as seen.
    result = await db.execute(select(Appointment.ownerUsername).where(Appointment.id == appt_id))
    owner_username = result.scalar_one_or_none()
    if not owner_username:
        raise HTTPException(404, "Запись не найдена")
    if current_user.username != owner_username and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет прав на отметку этой записи как просмотренной.")

    await db.execute(update(Appointment).where(Appointment.id == appt_id).values(isSeenByClient=1))
    await db.commit()
    return {"ok": True}

@router.get("/stats")
async def stats(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # P0: Assuming stats are only for admins, or all authenticated users.
    # For now, let's make it admin-only for demonstration.
    if current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Доступ к статистике только для администраторов.")

    res_total = await db.execute(select(func.count(Appointment.id)))
    res_sched = await db.execute(select(func.count(Appointment.id)).where(Appointment.status == 'scheduled'))
    res_comp = await db.execute(select(func.count(Appointment.id)).where(Appointment.status == 'completed'))
    return {
        "total": res_total.scalar(),
        "scheduled": res_sched.scalar(),
        "completed": res_comp.scalar()
    }
