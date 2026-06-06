import json
import uuid
from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, status, Response, Request
from core.limiter import limiter
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, func, or_, and_
from database import get_db
from models import AppointmentRequest, AppointmentResponse, AssignWasherRequest
from db_models import (
    Appointment, DeletedNotification, Service, ServiceConsumable, FcmToken,
    ConsumableUsageLog, WashTypeConsumable, Promo, PromoIncludedExtra,
    WashTypeIncludedExtra, User, Consumable, Shift,
)
from datetime import datetime, timedelta
from collections import defaultdict
from services.fcm_service import fcm_service
from services.workload_service import workload_service
from services.notification_service import add_notification
from services.auth_service import get_current_user, check_roles
from core.security import decrypt_token
from core.metrics import appointments_total
import structlog

logger = structlog.get_logger()

router = APIRouter(
    prefix="/api/appointments",
    tags=["appointments"],
    
)

@router.get(
    "/busy-slots",
    response_model=dict,
    summary="Занятые слоты",
    
)
@limiter.limit("30/minute")
async def get_busy_slots(request: Request, date: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await workload_service.get_busy_slots(db, date)

@router.get("/last-updated", response_model=dict)
@limiter.limit("30/minute")
async def get_last_updated(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    res = await db.execute(select(func.count(Appointment.id), func.max(Appointment.id)))
    count, max_id = res.one()
    return {"count": count, "max_id": max_id}

@router.get(
    "/",
    response_model=list[AppointmentResponse],
    summary="Список записей (с пагинацией)",
    
)
@limiter.limit("60/minute")
async def get_all(
    request: Request,
    response: Response,
    page: int = 1,
    date: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Построение запроса извлечения даты — dateTime хранится как ISO-строка YYYY-MM-DDTHH:mm:ss
    date_extract = func.substr(Appointment.dateTime, 1, 10)

    # 1. Get unique dates (days) in descending order
    if current_user.role == 'admin':
        dates_query = (
            select(date_extract)
            .where(Appointment.dateTime != None, Appointment.dateTime != '')
            .distinct()
            .order_by(date_extract.asc())
        )
    else:
        dates_query = (
            select(date_extract)
            .where(
                Appointment.dateTime != None,
                Appointment.dateTime != '',
                or_(Appointment.isHiddenFromAdmin == False, Appointment.isHiddenFromAdmin == None)
            )
            .distinct()
            .order_by(date_extract.asc())
        )

    dates_res = await db.execute(dates_query)
    unique_dates = [row[0] for row in dates_res.all() if row[0]]
    total_pages = len(unique_dates)

    logger.debug(
        "appointments_pagination",
        role=current_user.role,
        total_dates=total_pages,
        unique_dates=unique_dates[:5],
        requested_page=page,
        requested_date=date,
    )

    # 2. Determine target date
    target_date: Optional[str] = None
    if date:
        clean_date = date[:10]
        if clean_date in unique_dates:
            page = unique_dates.index(clean_date) + 1
            target_date = clean_date
        else:
            # Дата не найдена — возвращаем пустой результат, но сохраняем заголовки
            page = 1
            target_date = clean_date
    else:
        if total_pages > 0 and 1 <= page <= total_pages:
            target_date = unique_dates[page - 1]

    response.headers["X-Total-Pages"] = str(total_pages)
    response.headers["X-Current-Page"] = str(page)
    response.headers["X-Current-Date"] = target_date or ""
    response.headers["X-Unique-Dates"] = json.dumps(unique_dates)
    logger.info(
        "appointments_pagination_headers",
        x_total_pages=total_pages,
        x_current_page=page,
        x_current_date=target_date,
        x_unique_dates_count=len(unique_dates),
        unique_dates=unique_dates[:5],
    )

    if not target_date:
        logger.debug("appointments_empty", reason="no_target_date", total_pages=total_pages, page=page)
        return []

    # 3. Fetch appointments for the target date
    if current_user.role == 'admin':
        result = await db.execute(
            select(Appointment)
            .where(date_extract == target_date)
            .order_by(Appointment.dateTime.asc())
        )
    else:
        result = await db.execute(
            select(Appointment)
            .where(
                date_extract == target_date,
                or_(Appointment.isHiddenFromAdmin == False, Appointment.isHiddenFromAdmin == None)
            )
            .order_by(Appointment.dateTime.asc())
        )

    appointments = result.scalars().all()
    logger.debug(
        "appointments_fetched",
        role=current_user.role,
        target_date=target_date,
        count=len(appointments),
    )
    return appointments

@router.get("/by-owner/{username}", response_model=list[AppointmentResponse])
@limiter.limit("60/minute")
async def get_by_owner(request: Request, username: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # P0: IDOR check - only owner or admin can view.
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к записям этого пользователя.")
    result = await db.execute(select(Appointment).where(Appointment.ownerUsername == username.lower()).order_by(Appointment.dateTime.asc()))
    return result.scalars().all()

@router.get("/by-washer/{username}", response_model=list[AppointmentResponse])
@limiter.limit("60/minute")
async def get_by_washer(request: Request, username: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # P0: IDOR check - only washer or admin can view.
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к записям этого мойщика.")

    user_res = await db.execute(select(User).where(User.username == username.lower()))
    user = user_res.scalar_one_or_none()
    if not user:
        raise HTTPException(404, "Пользователь не найден")

    # 1. Явно назначенные записи
    safe_username = username.lower().replace('%', r'\%').replace('_', r'\_')
    result = await db.execute(
        select(Appointment)
        .where(Appointment.assignedWasher.like(f'%"{safe_username}"%', escape='\\'))
    )
    explicit = list(result.scalars().all())
    explicit_ids = {a.id for a in explicit}

    # 2. Записи, которые попадают в смены мойщика
    appt_date = func.substr(Appointment.dateTime, 1, 10)
    appt_time = func.substr(Appointment.dateTime, 12, 5)

    result2 = await db.execute(
        select(Appointment)
        .join(Shift, and_(
            Shift.userId == user.id,
            Shift.date == appt_date,
            appt_time >= Shift.startTime,
            appt_time <= Shift.endTime,
        ))
    )
    shift_based = [a for a in result2.scalars().all() if a.id not in explicit_ids]

    all_appts = explicit + shift_based
    all_appts.sort(key=lambda a: a.dateTime)
    return all_appts

async def _track_consumables_usage(db: AsyncSession, appt_id: str, wash_type_id: str, additional_services: list[str], promo_id: str = None):
    # 0. Восстановить остатки из предыдущих списаний и удалить старые логи
    old_logs_res = await db.execute(select(ConsumableUsageLog).where(ConsumableUsageLog.appointmentId == appt_id))
    for old_log in old_logs_res.scalars().all():
        res = await db.execute(select(Consumable).where(Consumable.id == old_log.consumableId))
        c = res.scalar_one_or_none()
        if c:
            c.currentStock += old_log.quantityUsed
        await db.delete(old_log)

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

    # 4. Уменьшение остатков + сохранение в лог (с блокировкой строки)
    for cid, qty in usage_map.items():
        res = await db.execute(select(Consumable).where(Consumable.id == cid).with_for_update())
        consumable = res.scalar_one_or_none()
        if consumable:
            consumable.currentStock = max(0.0, consumable.currentStock - qty)
            if consumable.currentStock < consumable.minStock:
                logger.warning(
                    "low_consumable_stock",
                    consumable=consumable.name,
                    current=consumable.currentStock,
                    minimum=consumable.minStock,
                )
        db.add(ConsumableUsageLog(
            appointmentId=appt_id,
            consumableId=cid,
            quantityUsed=qty,
            timestamp=datetime.now().isoformat()
        ))

@router.post(
    "/",
    response_model=AppointmentResponse,
    summary="Создание записи",
    
)
@limiter.limit("10/minute")
async def create(request: Request, req: AppointmentRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    owner_username = req.ownerUsername if req.ownerUsername else current_user.username
    
    if current_user.username != owner_username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Вы не можете создавать записи для других пользователей.")

    # Клиенты и мойщики могут создавать только запланированные записи
    effective_status = req.status if current_user.role == 'admin' else 'scheduled'

    # Находим свободный бокс
    duration = await workload_service.get_appointment_duration(db, req.washTypeId, req.additionalServices, req.promoId)
    box_idx = await workload_service.find_available_box(db, req.dateTime, duration)
    
    if box_idx == -1:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "К сожалению, на это время нет свободных боксов.")

    appt_data = {
        "id": req.id if req.id else str(uuid.uuid4()),
        "clientName": req.clientName,
        "carModel": req.carModel,
        "carNumber": req.carNumber,
        "dateTime": req.dateTime,
        "washTypeId": req.washTypeId,
        "additionalServices": req.additionalServices,
        "status": effective_status,
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
    appointments_total.labels(status=appt.status).inc()

    if effective_status == "completed":
        await _track_consumables_usage(db, req.id, req.washTypeId, req.additionalServices, req.promoId)
        await db.commit()

    if appt.ownerUsername:
        res = await db.execute(select(FcmToken.token).where(FcmToken.username == appt.ownerUsername))
        encrypted_tokens = res.scalars().all()
        if encrypted_tokens:
            tokens = []
            for t in encrypted_tokens:
                try:
                    tokens.append(decrypt_token(t))
                except Exception:
                    pass
            if tokens:
                await fcm_service.send_notification_to_tokens(
                    tokens,
                    title="Новая запись создана!",
                    body=f"Ваша запись на мойку {appt.carModel} в {appt.dateTime} успешно создана."
                )

    appointments_total.labels(status=effective_status).inc()
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


@router.put(
    "/{appt_id}",
    response_model=AppointmentResponse,
    summary="Редактирование записи",
    
)
@limiter.limit("10/minute")
async def update_appt(request: Request, appt_id: str, req: AppointmentRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    result = await db.execute(select(Appointment).where(Appointment.id == appt_id))
    appt = result.scalar_one_or_none()
    if not appt:
        raise HTTPException(404, "Запись не найдена")

    # Сохраняем оригинальные значения для сравнения и выявления изменений админом
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
    logger.debug("updating_appointment", appt_id=appt_id, username=current_user.username, role=current_user.role)
    logger.debug("appointment_owner", owner=appt.ownerUsername)

    # Разрешаем владельцу, админу или мойщику редактировать запись
    # Проверяем, является ли текущий пользователь владельцем, админом или мойщиком
    is_owner = current_user.username == appt.ownerUsername
    is_admin = current_user.role == 'admin'
    is_washer = current_user.role == 'washer'

    assigned_washers = json.loads(appt.assignedWasher) if appt.assignedWasher else []
    is_assigned_washer = is_washer and current_user.username in assigned_washers

    # Мойщик может редактировать записи, которые попадают в его смену
    is_shift_washer = False
    if is_washer and not is_assigned_washer:
        appt_date = appt.dateTime[:10] if appt.dateTime else None
        appt_time = appt.dateTime[11:16] if appt.dateTime and len(appt.dateTime) >= 16 else None
        if appt_date and appt_time:
            shift_res = await db.execute(
                select(Shift).where(
                    Shift.userId == current_user.id,
                    Shift.date == appt_date,
                    Shift.startTime <= appt_time,
                    Shift.endTime >= appt_time,
                )
            )
            is_shift_washer = shift_res.scalar_one_or_none() is not None

    if not (is_owner or is_admin or is_assigned_washer or is_shift_washer):
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
    if req.status != original_status:
        appointments_total.labels(status=req.status).inc()
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

        # Определяем, внёс ли админ изменения, требующие уведомления клиента
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
            logger.info("admin_changes_triggered", appt_id=appt.id)
            appt.isModifiedByAdmin = 1
            appt.isSeenByClient = 0
        # Если изменений нет, флаги (isModifiedByAdmin, isSeenByClient) остаются без изменений

    elif current_user.role == 'washer':
        # Если статус изменился, помечаем, что это изменение от мойщика
        if old_status != req.status:
            appt.isModifiedByWasher = 1
            appt.isSeenByClient = 0
    
    await db.commit()

    # Send Telegram notification if status changed to in_progress or completed
    if old_status != req.status and req.status in ("in_progress", "completed"):
        client_result = await db.execute(
            select(User.telegramId).where(User.username == appt.ownerUsername)
        )
        client_tg = client_result.scalar_one_or_none()
        if client_tg:
            status_text = "началась" if req.status == "in_progress" else "завершена"
            message = (
                f"{'🚗' if req.status == 'in_progress' else '✅'} "
                f"Ваша мойка {status_text}!\n"
                f"{appt.carModel}, бокс {appt.box_index + 1}"
            )
            await add_notification(db, client_tg, message)

    if req.status == "completed":
        await _track_consumables_usage(db, appt_id, req.washTypeId, req.additionalServices, req.promoId)
        await db.commit()

    if appt.ownerUsername:
        tokens_res = await db.execute(select(FcmToken.token).where(FcmToken.username == appt.ownerUsername))
        encrypted_tokens = tokens_res.scalars().all()
        
        if encrypted_tokens:
            client_tokens = []
            for t in encrypted_tokens:
                try:
                    client_tokens.append(decrypt_token(t))
                except Exception:
                    pass
            
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

@router.delete(
    "/{appt_id}",
    summary="Удаление записи",
    
)
@limiter.limit("10/minute")
async def delete_appt(request: Request, appt_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
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
@limiter.limit("10/minute")
async def toggle_favorite(request: Request, appt_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
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

@router.post(
    "/{appt_id}/assign-washer",
    summary="Назначение мойщика",
    
)
@limiter.limit("10/minute")
async def assign_washer(request: Request, appt_id: str, req: AssignWasherRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(check_roles(['admin']))):
    # Только администратор может назначать/снимать мойщиков.
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
        
        # Проверка на пересечение времени с другими назначенными записями
        safe_username = username.replace('%', r'\%').replace('_', r'\_')
        conflict_res = await db.execute(
            select(Appointment).where(
                Appointment.assignedWasher.like(f'%{safe_username}%', escape='\\'),
                Appointment.status != 'cancelled',
                Appointment.id != appt_id
            )
        )
        try:
            appt_start = workload_service._safe_parse_iso(appt.dateTime)
        except ValueError:
            raise HTTPException(400, "Некорректная дата записи")
        appt_duration = await workload_service.get_appointment_duration(db, appt.washTypeId, appt.additionalServices, appt.promoId)
        appt_end = appt_start + timedelta(minutes=appt_duration)
        for other in conflict_res.scalars().all():
            try:
                other_start = workload_service._safe_parse_iso(other.dateTime)
            except ValueError:
                continue
            other_duration = await workload_service.get_appointment_duration(db, other.washTypeId, other.additionalServices, other.promoId)
            other_end = other_start + timedelta(minutes=other_duration)
            if appt_start < other_end and appt_end > other_start:
                raise HTTPException(400, f"Мойщик {username} уже назначен на пересекающееся время")
        
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
                logger.warning("token_decrypt_failed", username=username, error=str(e))
        
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
                logger.info("notification_sent", event="assignment", username=username)
            else:
                # Снят
                await fcm_service.send_notification_to_tokens(
                    tokens,
                    title="Запись снята",
                    body=f"Вы были сняты с записи на мойку {appt.carModel} {dt_str}.",
                    data={"type": "appointment_updated", "id": appt.id}
                )
                logger.info("notification_sent", event="removal", username=username)

    return appt

@router.get("/deleted-notification/{username}")
@limiter.limit("60/minute")
async def get_deleted_notification(request: Request, username: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # P0: IDOR check - Only the user themselves or admin can check.
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет доступа к этому уведомлению.")
    result = await db.execute(select(func.count(DeletedNotification.id)).where(DeletedNotification.username == username.lower()))
    count = result.scalar()
    return {"hasNotification": count > 0}

@router.delete("/deleted-notification/{username}")
@limiter.limit("10/minute")
async def clear_deleted_notification(request: Request, username: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # P0: IDOR check - Only the user themselves or admin can clear.
    if current_user.username != username.lower() and current_user.role != 'admin':
        raise HTTPException(status.HTTP_403_FORBIDDEN, "У вас нет прав на очистку этого уведомления.")
    await db.execute(delete(DeletedNotification).where(DeletedNotification.username == username.lower()))
    await db.commit()
    return {"ok": True}

@router.post("/{appt_id}/clear-admin-flag")
@limiter.limit("10/minute")
async def clear_admin_flag(request: Request, appt_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
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
@limiter.limit("10/minute")
async def mark_appointment_seen(request: Request, appt_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
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
@limiter.limit("60/minute")
async def stats(request: Request, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # P0: Assuming stats are only for admins, or all authenticated users.
    # Пока оставляем только для администраторов.
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
