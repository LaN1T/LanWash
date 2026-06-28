import json
import uuid
from collections import defaultdict
from datetime import date, datetime, time, timedelta
from typing import Optional

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from sqlalchemy import String, and_, delete, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from core.limiter import limiter
from core.metrics import appointments_total
from core.pagination import PaginationParams, paginate
from core.security import decrypt_token
from db.session import get_db
from models import (
    Appointment,
    AppointmentWasher,
    Car,
    Consumable,
    ConsumableUsageLog,
    DeletedNotification,
    FcmToken,
    LogEntry,
    ServiceConsumable,
    Shift,
    Subscription,
    User,
    WashTypeConsumable,
)
from repositories.fcm_token import FcmTokenRepository
from repositories.promo import PromoRepository
from repositories.promo_included_extra import PromoIncludedExtraRepository
from repositories.service import ServiceRepository
from repositories.subscription import SubscriptionRepository
from repositories.wash_type import WashTypeRepository
from repositories.wash_type_included_extra import WashTypeIncludedExtraRepository
from schemas import (
    AppointmentRequest,
    AppointmentResponse,
    AssignWasherRequest,
    CancelReasonRequest,
    LateReportRequest,
    QrScanRequest,
)
from services.appointment_ws_manager import appointment_ws_manager
from services.audit_service import log_admin_action
from services.auth_service import check_roles, get_current_user
from services.fcm_service import fcm_service
from services.notification_service import add_notification
from services.workload_service import workload_service

logger = structlog.get_logger()


async def _auto_assign_washer(db: AsyncSession, date_time: datetime) -> Optional[str]:
    """Find the washer on shift for the given date with the fewest assignments."""
    target_date = date_time.date()

    # Find washers on confirmed shift for this date
    shift_result = await db.execute(
        select(Shift.userId).where(
            and_(Shift.date == target_date, Shift.status == "confirmed")
        )
    )
    washer_ids = [row[0] for row in shift_result.all()]
    if not washer_ids:
        return None

    # Get usernames for these washers
    user_result = await db.execute(
        select(User.id, User.username).where(User.id.in_(washer_ids))
    )
    id_to_username = {row[0]: row[1] for row in user_result.all()}

    # Count appointments per washer on this date
    appt_result = await db.execute(
        select(AppointmentWasher.washerUsername)
        .join(Appointment)
        .where(
            and_(
                Appointment.date == target_date,
                Appointment.status != "cancelled",
            )
        )
    )
    counts: dict[str, int] = defaultdict(int)
    for (username,) in appt_result.all():
        if username:
            counts[username] += 1

    # Pick washer with fewest assignments
    best_washer = None
    best_count = float("inf")
    for uid in washer_ids:
        username = id_to_username.get(uid)
        if username is None:
            continue
        c = counts.get(username, 0)
        if c < best_count:
            best_count = c
            best_washer = username

    return best_washer


def _parse_time(value) -> Optional[time]:
    """Parse a time value from a Python object or string.

    Handles DB schema mismatches where shift / appointment columns may be
    stored as VARCHAR instead of native TIME/DATETIME types.
    """
    if value is None:
        return None
    if isinstance(value, time):
        return value
    if isinstance(value, datetime):
        return value.time()
    if isinstance(value, str):
        value = value.strip()
        if "T" in value:
            try:
                return datetime.fromisoformat(value).time()
            except ValueError:
                return None
        for fmt in ("%H:%M:%S", "%H:%M"):
            try:
                return datetime.strptime(value, fmt).time()
            except ValueError:
                continue
    return None


def _parse_date(value) -> Optional[date]:
    """Parse a date value from a Python object or string."""
    if value is None:
        return None
    if isinstance(value, date) and not isinstance(value, datetime):
        return value
    if isinstance(value, str):
        try:
            return date.fromisoformat(value)
        except ValueError:
            return None
    return None


async def _notify_fcm(
    request: Request, tokens: list[str], title: str, body: str, data: dict | None = None
):
    """Enqueue FCM notification via ARQ or send inline if worker is unavailable."""
    arq_pool = getattr(request.app.state, "arq_pool", None)
    if arq_pool:
        await arq_pool.enqueue_job("send_fcm_notification", tokens, title, body, data)
    else:
        try:
            await fcm_service.send_notification_to_tokens(tokens, title, body, data)
        except Exception as e:
            logger.warning("fcm_send_failed", error=str(e))


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
async def get_busy_slots(
    request: Request,
    date: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await workload_service.get_busy_slots(db, date)


@router.get("/last-updated", response_model=dict)
@limiter.limit("30/minute")
async def get_last_updated(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
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
    date_str: Optional[str] = Query(None, alias="date"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Use the indexed `date` column (YYYY-MM-DD) instead of func.substr(dateTime).
    # Cap unique dates to the last 90 days to avoid unbounded headers/memory
    cutoff_date = date.today() - timedelta(days=90)

    # 1. Get unique dates (days) in descending order
    if current_user.role == "admin":
        dates_query = (
            select(Appointment.date)
            .where(
                Appointment.date.isnot(None),
                Appointment.date >= cutoff_date,
            )
            .distinct()
            .order_by(Appointment.date.asc())
        )
    else:
        # P0: IDOR fix — clients only see their own appointments
        date_filters = [
            Appointment.date.isnot(None),
            Appointment.date >= cutoff_date,
            or_(
                Appointment.isHiddenFromAdmin.is_(False),
                Appointment.isHiddenFromAdmin.is_(None),
            ),
        ]
        if current_user.role == "client":
            date_filters.append(Appointment.ownerUsername == current_user.username)
        dates_query = (
            select(Appointment.date)
            .where(and_(*date_filters))
            .distinct()
            .order_by(Appointment.date.asc())
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
        requested_date=date_str,
    )

    # 2. Determine target date
    target_date: Optional[date] = None
    if date_str:
        clean_date = date.fromisoformat(date_str[:10])
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
    response.headers["X-Current-Date"] = target_date.isoformat() if target_date else ""
    response.headers["X-Unique-Dates"] = json.dumps(
        [d.isoformat() for d in unique_dates]
    )
    logger.info(
        "appointments_pagination_headers",
        x_total_pages=total_pages,
        x_current_page=page,
        x_current_date=target_date,
        x_unique_dates_count=len(unique_dates),
        unique_dates=unique_dates[:5],
    )

    if not target_date:
        logger.debug(
            "appointments_empty",
            reason="no_target_date",
            total_pages=total_pages,
            page=page,
        )
        return []

    # 3. Fetch appointments for the target date
    if current_user.role == "admin":
        result = await db.execute(
            select(Appointment)
            .where(Appointment.date == target_date)
            .order_by(Appointment.dateTime.asc())
        )
    else:
        # P0: IDOR fix — clients only see their own appointments
        appt_filters = [
            Appointment.date == target_date,
            or_(
                Appointment.isHiddenFromAdmin.is_(False),
                Appointment.isHiddenFromAdmin.is_(None),
            ),
        ]
        if current_user.role == "client":
            appt_filters.append(Appointment.ownerUsername == current_user.username)
        result = await db.execute(
            select(Appointment)
            .where(and_(*appt_filters))
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
async def get_by_owner(
    request: Request,
    username: str,
    pagination: PaginationParams = Depends(),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # P0: IDOR check - only owner or admin can view.
    if current_user.username != username.lower() and current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "У вас нет доступа к записям этого пользователя."
        )
    query = (
        select(Appointment)
        .where(Appointment.ownerUsername == username.lower())
        .order_by(Appointment.dateTime.asc())
    )
    _, items = await paginate(query, db, pagination)
    return items


@router.get("/by-washer/{username}", response_model=list[AppointmentResponse])
@limiter.limit("60/minute")
async def get_by_washer(
    request: Request,
    username: str,
    pagination: PaginationParams = Depends(),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # P0: IDOR check - only washer or admin can view.
    if current_user.username != username.lower() and current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "У вас нет доступа к записям этого мойщика."
        )

    user_res = await db.execute(select(User).where(User.username == username.lower()))
    user = user_res.scalar_one_or_none()
    if not user:
        raise HTTPException(404, "Пользователь не найден")

    username_lower = username.lower()

    # 1. Appointments explicitly assigned to this washer.
    assigned_result = await db.execute(
        select(Appointment.id)
        .join(AppointmentWasher)
        .where(AppointmentWasher.washerUsername == username_lower)
    )
    appt_ids = {row[0] for row in assigned_result.all()}

    # 2. Appointments that fall inside one of the washer's confirmed shifts.
    #    We match dates/times in Python so the code is robust against schema
    #    mismatches (e.g. TIME/DATE columns stored as VARCHAR).
    shift_result = await db.execute(
        select(Shift).where(Shift.userId == user.id, Shift.status == "confirmed")
    )
    shifts = shift_result.scalars().all()
    if shifts:
        intervals: dict[date, list[tuple[time, time]]] = defaultdict(list)
        for s in shifts:
            shift_date = _parse_date(s.date)
            start = _parse_time(s.startTime)
            end = _parse_time(s.endTime)
            if shift_date is not None and start is not None and end is not None:
                intervals[shift_date].append((start, end))

        if intervals:
            date_strings = [d.isoformat() for d in intervals.keys()]
            appt_result = await db.execute(
                select(Appointment.id, Appointment.date, Appointment.dateTime).where(
                    func.cast(Appointment.date, String).in_(date_strings)
                )
            )
            for appt_id, appt_date, appt_dt in appt_result.all():
                parsed_date = _parse_date(appt_date)
                parsed_time = _parse_time(appt_dt)
                if parsed_date is None or parsed_time is None:
                    continue
                for start, end in intervals.get(parsed_date, []):
                    if start <= parsed_time <= end:
                        appt_ids.add(appt_id)
                        break

    # 3. Appointments created by the washer themselves.
    if user.role == "washer":
        own_result = await db.execute(
            select(Appointment.id).where(Appointment.ownerUsername == username_lower)
        )
        appt_ids.update(row[0] for row in own_result.all())

    if not appt_ids:
        return []

    query = (
        select(Appointment)
        .where(Appointment.id.in_(appt_ids))
        .order_by(Appointment.dateTime.asc())
    )
    _, items = await paginate(query, db, pagination)
    return items


async def _track_consumables_usage(
    request: Request | None,
    db: AsyncSession,
    appt_id: str,
    wash_type_id: str,
    additional_services: list[str],
    promo_id: str = None,
):
    # 0. Восстановить остатки из предыдущих списаний и удалить старые логи
    old_logs_res = await db.execute(
        select(ConsumableUsageLog).where(ConsumableUsageLog.appointmentId == appt_id)
    )
    old_logs = old_logs_res.scalars().all()
    if old_logs:
        consumable_ids = {log.consumableId for log in old_logs}
        cons_res = await db.execute(
            select(Consumable).where(Consumable.id.in_(consumable_ids))
        )
        cons_map = {c.id: c for c in cons_res.scalars().all()}
        for old_log in old_logs:
            c = cons_map.get(old_log.consumableId)
            if c:
                c.currentStock += old_log.quantityUsed
            await db.delete(old_log)

    # 1. Сбор расходников из типа мойки
    res_wt = await db.execute(
        select(
            WashTypeConsumable.consumableId, WashTypeConsumable.quantity_per_service
        ).where(WashTypeConsumable.washTypeId == wash_type_id)
    )
    usage_map = {row[0]: float(row[1]) for row in res_wt.all()}

    # 2. Сбор расходников из промо (упрощённо — пока не учитываем)
    # При необходимости:
    # await db.execute(
    #     select(PromoIncludedExtra.extraServiceId)
    #     .where(PromoIncludedExtra.promoId == promo_id)
    # )

    # 3. Сбор расходников из доп.услуг
    if additional_services:
        try:
            # Если это JSON строка, парсим её
            service_ids = (
                json.loads(additional_services)
                if isinstance(additional_services, str)
                else additional_services
            )
        except Exception:
            service_ids = (
                additional_services if isinstance(additional_services, list) else []
            )

        if service_ids:
            res_svc = await db.execute(
                select(
                    ServiceConsumable.consumableId,
                    ServiceConsumable.quantity_per_service,
                ).where(ServiceConsumable.serviceId.in_(service_ids))
            )
            for cid, qty in res_svc.all():
                usage_map[cid] = usage_map.get(cid, 0.0) + float(qty)

    # 4. Уменьшение остатков + пакетное сохранение в лог (с блокировкой строк)
    newly_low: list[Consumable] = []
    if usage_map:
        cids = list(usage_map.keys())
        cons_res = await db.execute(
            select(Consumable).where(Consumable.id.in_(cids)).with_for_update()
        )
        cons_map = {c.id: c for c in cons_res.scalars().all()}
        now = datetime.now()
        logs = []
        for cid, qty in usage_map.items():
            consumable = cons_map.get(cid)
            if consumable:
                was_low = consumable.currentStock < consumable.minStock
                consumable.currentStock = max(0.0, consumable.currentStock - qty)
                if consumable.currentStock < consumable.minStock:
                    logger.warning(
                        "low_consumable_stock",
                        consumable=consumable.name,
                        current=consumable.currentStock,
                        minimum=consumable.minStock,
                    )
                    if not was_low:
                        newly_low.append(consumable)
            logs.append(
                ConsumableUsageLog(
                    appointmentId=appt_id,
                    consumableId=cid,
                    quantityUsed=qty,
                    timestamp=now,
                )
            )
        db.add_all(logs)

    # 5. Уведомление администраторам о новом низком остатке
    if request and newly_low:
        admin_tokens = await FcmTokenRepository(db).list_admin_tokens()
        if admin_tokens:
            tokens: list[str] = []
            seen: set[str] = set()
            for t in admin_tokens:
                if t in seen:
                    continue
                seen.add(t)
                try:
                    tokens.append(decrypt_token(t))
                except Exception:
                    pass
            if tokens:
                for consumable in newly_low:
                    await _notify_fcm(
                        request,
                        tokens,
                        "Низкий остаток расходника",
                        (
                            f"{consumable.name}: осталось {consumable.currentStock} "
                            f"(мин. {consumable.minStock})"
                        ),
                        {"type": "low_stock", "consumableId": consumable.id},
                    )


async def _calculate_client_prices(
    db: AsyncSession,
    wash_type_id: str,
    additional_services_json: str,
    promo_id: Optional[str],
    date_time: datetime,
) -> tuple[int, int, int]:
    """Calculate original/promo/paid prices for a client-created appointment.

    Returns (original_price, promo_price, paid_price). Raises HTTPException
    if the selected promo is invalid or not applicable.
    """
    promo = None
    if promo_id:
        promo_repo = PromoRepository(db)
        promo = await promo_repo.get_by_id(promo_id)
        if not promo:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST, "Указанная акция не найдена"
            )
        if promo.washTypeId != wash_type_id:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                "Акция не применима к выбранному типу мойки",
            )
        if promo.weekendOnly and date_time.weekday() < 5:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                "Акция действует только по выходным",
            )

    wash_type_repo = WashTypeRepository(db)
    base_prices = await wash_type_repo.get_base_prices([wash_type_id])
    base_price = base_prices.get(wash_type_id, 0)

    wt_extras_repo = WashTypeIncludedExtraRepository(db)
    wt_included = set(await wt_extras_repo.list_extra_ids_for_wash_type(wash_type_id))
    promo_included: set[str] = set()
    if promo:
        promo_extras_repo = PromoIncludedExtraRepository(db)
        promo_included_map = await promo_extras_repo.list_extras_for_promos([promo.id])
        promo_included = set(promo_included_map.get(promo.id, []))

    locked_extras = wt_included | promo_included

    try:
        extra_ids = json.loads(additional_services_json or "[]")
    except Exception:
        extra_ids = []
    filtered_ids = [eid for eid in extra_ids if eid not in locked_extras]

    extras_price = 0
    if filtered_ids:
        service_repo = ServiceRepository(db)
        service_prices = await service_repo.get_prices(filtered_ids)
        extras_price = sum(service_prices.get(eid, 0) for eid in filtered_ids)

    regular_price = base_price + extras_price

    if promo:
        if promo.discountPercent > 0:
            promo_base_price = base_price * (100 - promo.discountPercent) // 100
        else:
            promo_base_price = promo.price
        paid_price = promo_base_price + extras_price
    else:
        promo_base_price = 0
        paid_price = regular_price

    return regular_price, promo_base_price, paid_price


@router.post(
    "/",
    response_model=AppointmentResponse,
    summary="Создание записи",
)
@limiter.limit("10/minute")
async def create(
    request: Request,
    req: AppointmentRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    owner_username = req.ownerUsername if req.ownerUsername else current_user.username
    if current_user.username != owner_username.lower() and current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "Вы не можете создавать записи для других пользователей.",
        )

    # Клиенты и мойщики могут создавать только запланированные записи
    effective_status = req.status if current_user.role == "admin" else "scheduled"

    # Если указан carId, валидируем принадлежность и подставляем данные
    car_model = req.carModel
    car_number = req.carNumber
    if req.carId is not None:
        # Determine the target user for car ownership validation
        target_user_id = current_user.id
        if (
            current_user.role == "admin"
            and current_user.username != owner_username.lower()
        ):
            target_user_res = await db.execute(
                select(User).where(User.username == owner_username.lower())
            )
            target_user = target_user_res.scalar_one_or_none()
            if target_user:
                target_user_id = target_user.id

        car_res = await db.execute(
            select(Car).where(Car.id == req.carId, Car.userId == target_user_id)
        )
        car = car_res.scalar_one_or_none()
        if not car:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                "Указанный автомобиль не найден или не принадлежит клиенту",
            )
        car_model = f"{car.brand} {car.model}".strip()
        car_number = car.number

    # Determine target user ID for subscription lookup
    target_user_id = current_user.id
    if current_user.role == "admin" and current_user.username != owner_username.lower():
        target_user_res = await db.execute(
            select(User).where(User.username == owner_username.lower())
        )
        target_user = target_user_res.scalar_one_or_none()
        if target_user:
            target_user_id = target_user.id

    # Non-admins cannot set prices; server calculates them from the catalog and promo.
    if current_user.role != "admin":
        (
            req.originalPrice,
            req.promoPrice,
            req.paidPrice,
        ) = await _calculate_client_prices(
            db,
            req.washTypeId,
            req.additionalServices,
            req.promoId,
            req.dateTime,
        )

    # Check for active subscription
    subscription_id = req.subscriptionId
    if subscription_id is not None:
        # Client explicitly chose a subscription; validate it belongs to the user,
        # matches the wash type and has remaining washes.
        sub_repo = SubscriptionRepository(db)
        sub = await sub_repo.get_active_for_user_and_wash_type_with_lock(
            subscription_id, target_user_id, req.washTypeId
        )
        if not sub:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                "Абонемент не найден, не активен или не подходит для этого типа мойки",
            )
        sub.usedWashes += 1
        # Subscription washes are free; keep original/promo prices for reporting.
        req.paidPrice = 0
    else:
        # Auto-apply an active subscription if the client did not choose one.
        today = date.today()
        sub_res = await db.execute(
            select(Subscription)
            .where(
                Subscription.userId == target_user_id,
                Subscription.washTypeId == req.washTypeId,
                Subscription.usedWashes < Subscription.totalWashes,
                or_(
                    Subscription.validUntil.is_(None), Subscription.validUntil >= today
                ),
            )
            .with_for_update()
        )
        sub = sub_res.scalar_one_or_none()

        if sub:
            subscription_id = sub.id
            sub.usedWashes += 1
            # Subscription washes are free; keep original/promo prices for reporting.
            req.paidPrice = 0

    # Находим свободный бокс
    duration = await workload_service.get_appointment_duration(
        db, req.washTypeId, req.additionalServices, req.promoId
    )
    box_idx = await workload_service.find_available_box(db, req.dateTime, duration)

    if box_idx == -1:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "К сожалению, на это время нет свободных боксов.",
        )

    appt_data = {
        "id": req.id if req.id else str(uuid.uuid4()),
        "userId": target_user_id,
        "clientName": req.clientName,
        "carModel": car_model,
        "carNumber": car_number,
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
        "subscriptionId": subscription_id,
        "box_index": box_idx,
    }

    if current_user.role == "admin":
        assigned = req.assignedWasher
        if not assigned or assigned == "[]":
            auto_washer = await _auto_assign_washer(db, req.dateTime)
            if auto_washer:
                assigned = json.dumps([auto_washer])
        appt_data.update(
            {
                "isModifiedByAdmin": int(req.isModifiedByAdmin),
                "isModifiedByWasher": int(req.isModifiedByWasher),
                "isSeenByClient": 1
                if not (req.isModifiedByAdmin or req.isModifiedByWasher)
                else 0,
                "originalPrice": req.originalPrice,
                "assignedWasher": assigned,
            }
        )
    else:
        assigned = "[]"
        auto_washer = await _auto_assign_washer(db, req.dateTime)
        if auto_washer:
            assigned = json.dumps([auto_washer])
        appt_data.update(
            {
                "isModifiedByAdmin": 0,
                "isModifiedByWasher": 0,
                "isSeenByClient": 1,
                "originalPrice": req.paidPrice
                if req.originalPrice == 0
                else req.originalPrice,
                "assignedWasher": assigned,
            }
        )

    appt = Appointment(**appt_data)
    db.add(appt)
    await db.commit()
    appointments_total.labels(status=appt.status).inc()

    if effective_status == "completed":
        await _track_consumables_usage(
            request, db, req.id, req.washTypeId, req.additionalServices, req.promoId
        )
        await db.commit()

    if appt.ownerUsername:
        res = await db.execute(
            select(FcmToken.token).where(FcmToken.username == appt.ownerUsername)
        )
        encrypted_tokens = res.scalars().all()
        if encrypted_tokens:
            tokens = []
            for t in encrypted_tokens:
                try:
                    tokens.append(decrypt_token(t))
                except Exception:
                    pass
            if tokens:
                await _notify_fcm(
                    request,
                    tokens,
                    "Новая запись создана!",
                    (
                        f"Ваша запись на мойку {appt.carModel} "
                        f"в {appt.dateTime} успешно создана."
                    ),
                    {},
                )

    appointments_total.labels(status=effective_status).inc()
    await db.refresh(appt)
    try:
        await appointment_ws_manager.notify_appointment(db, appt, "created")
    except Exception as e:
        logger.warning("appointment_ws_broadcast_failed", event="created", error=str(e))

    return appt


def format_date(dt_str):
    if not dt_str:
        return "неизвестное время"
    try:
        # Пытаемся распарсить, если это строка ISO
        if isinstance(dt_str, str):
            dt = datetime.fromisoformat(dt_str.replace("Z", "+00:00"))
        else:
            dt = dt_str
        return dt.strftime("%d.%m %H:%M")
    except Exception:
        return str(dt_str)


@router.put(
    "/{appt_id}",
    response_model=AppointmentResponse,
    summary="Редактирование записи",
)
@limiter.limit("10/minute")
async def update_appt(
    request: Request,
    appt_id: str,
    req: AppointmentRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
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
    logger.debug(
        "updating_appointment",
        appt_id=appt_id,
        username=current_user.username,
        role=current_user.role,
    )
    logger.debug("appointment_owner", owner=appt.ownerUsername)

    # Разрешаем владельцу, админу или мойщику редактировать запись
    # Проверяем, является ли текущий пользователь владельцем, админом или мойщиком
    is_owner = current_user.username == appt.ownerUsername
    is_admin = current_user.role == "admin"
    is_washer = current_user.role == "washer"

    assigned_washers = json.loads(appt.assignedWasher) if appt.assignedWasher else []
    is_assigned_washer = is_washer and current_user.username in assigned_washers

    # Мойщик может редактировать записи, которые попадают в его смену
    is_shift_washer = False
    if is_washer and not is_assigned_washer and appt.dateTime:
        appt_date = appt.dateTime.date()
        appt_time = appt.dateTime.time()
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
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "У вас нет прав на редактирование этой записи."
        )

    # Washers can only change status and notes
    if is_washer and not is_admin:
        req.clientName = original_clientName
        req.carModel = original_carModel
        req.carNumber = original_carNumber
        req.dateTime = original_dateTime
        req.washTypeId = original_washTypeId
        req.additionalServices = original_additionalServices
        req.isFavorite = bool(original_isFavorite)
        req.promoPrice = original_promoPrice
        req.paidPrice = original_paidPrice
        req.promoId = original_promoId
        req.assignedWasher = original_assignedWasher
        req.box_index = original_box_index

    old_status = appt.status
    old_datetime = appt.dateTime
    old_assigned_washer = appt.assignedWasher

    # Проверка доступности бокса, если время или услуги изменились
    duration = await workload_service.get_appointment_duration(
        db, req.washTypeId, req.additionalServices, req.promoId
    )
    box_idx = await workload_service.find_available_box(
        db, req.dateTime, duration, exclude_appt_id=appt_id
    )

    if box_idx == -1:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "К сожалению, на это время нет свободных боксов.",
        )

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

    if current_user.role == "admin":
        appt.ownerUsername = req.ownerUsername.lower()
        appt.originalPrice = req.originalPrice
        appt.assignedWasher = req.assignedWasher

        # Определяем, внёс ли админ изменения, требующие уведомления клиента
        def normalize_json(s):
            try:
                return (
                    sorted(json.loads(s))
                    if isinstance(json.loads(s), list)
                    else json.loads(s)
                )
            except Exception:
                return s

        admin_made_changes = False
        if appt.clientName != original_clientName:
            admin_made_changes = True
        if appt.carModel != original_carModel:
            admin_made_changes = True
        if appt.carNumber != original_carNumber:
            admin_made_changes = True
        if appt.dateTime != original_dateTime:
            admin_made_changes = True
        if appt.washTypeId != original_washTypeId:
            admin_made_changes = True
        if normalize_json(appt.additionalServices) != normalize_json(
            original_additionalServices
        ):
            admin_made_changes = True
        if appt.status != original_status:
            admin_made_changes = True
        if appt.notes != original_notes:
            admin_made_changes = True
        if appt.isFavorite != original_isFavorite:
            admin_made_changes = True
        if appt.ownerUsername != original_ownerUsername:
            admin_made_changes = True
        if appt.promoPrice != original_promoPrice:
            admin_made_changes = True
        if appt.paidPrice != original_paidPrice:
            admin_made_changes = True
        if appt.originalPrice != original_originalPrice:
            admin_made_changes = True
        if normalize_json(appt.assignedWasher) != normalize_json(
            original_assignedWasher
        ):
            admin_made_changes = True
        if appt.promoId != original_promoId:
            admin_made_changes = True
        if appt.box_index != original_box_index:
            admin_made_changes = True

        if admin_made_changes:
            logger.info("admin_changes_triggered", appt_id=appt.id)
            appt.isModifiedByAdmin = 1
            appt.isSeenByClient = 0
            old_values = {
                "clientName": original_clientName,
                "carModel": original_carModel,
                "carNumber": original_carNumber,
                "dateTime": original_dateTime,
                "washTypeId": original_washTypeId,
                "additionalServices": original_additionalServices,
                "status": original_status,
                "notes": original_notes,
                "isFavorite": original_isFavorite,
                "ownerUsername": original_ownerUsername,
                "promoPrice": original_promoPrice,
                "paidPrice": original_paidPrice,
                "originalPrice": original_originalPrice,
                "assignedWasher": original_assignedWasher,
                "promoId": original_promoId,
                "box_index": original_box_index,
            }
            new_values = {
                "clientName": appt.clientName,
                "carModel": appt.carModel,
                "carNumber": appt.carNumber,
                "dateTime": appt.dateTime,
                "washTypeId": appt.washTypeId,
                "additionalServices": appt.additionalServices,
                "status": appt.status,
                "notes": appt.notes,
                "isFavorite": appt.isFavorite,
                "ownerUsername": appt.ownerUsername,
                "promoPrice": appt.promoPrice,
                "paidPrice": appt.paidPrice,
                "originalPrice": appt.originalPrice,
                "assignedWasher": appt.assignedWasher,
                "promoId": appt.promoId,
                "box_index": appt.box_index,
            }
            await log_admin_action(
                db,
                current_user,
                action="update_appointment",
                entity_type="appointment",
                entity_id=appt.id,
                old_values=old_values,
                new_values=new_values,
                request=request,
            )
        # Если изменений нет, флаги (isModifiedByAdmin, isSeenByClient)
        # остаются без изменений

    elif current_user.role == "washer":
        # Если статус изменился, помечаем, что это изменение от мойщика
        if old_status != req.status:
            appt.isModifiedByWasher = 1
            appt.isSeenByClient = 0
            db.add(
                LogEntry(
                    username=current_user.username,
                    action="Изменение статуса мойки",
                    details=(
                        f"Запись {appt.id} ({appt.carModel}, {appt.carNumber}): "
                        f"{old_status} → {req.status}"
                    ),
                    timestamp=datetime.now(),
                )
            )

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
        await _track_consumables_usage(
            request, db, appt_id, req.washTypeId, req.additionalServices, req.promoId
        )
        await db.commit()

    if appt.ownerUsername:
        tokens_res = await db.execute(
            select(FcmToken.token).where(FcmToken.username == appt.ownerUsername)
        )
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
                    title, body = (
                        "Запись завершена",
                        "Ваша запись завершена. Спасибо, что выбрали нас!",
                    )
                elif appt.status == "in_progress":
                    title, body = (
                        "Начало обслуживания",
                        f"Ваш авто в боксе {appt.box_index + 1}. Мы начали!",
                    )
                elif appt.status == "cancelled":
                    title, body = (
                        "Запись отменена",
                        f"К сожалению, запись на {dt_str} была отменена.",
                    )
                elif appt.status == "scheduled":
                    title, body = (
                        "Запись подтверждена",
                        f"Вы записались на мойку {dt_str}. Бокс {appt.box_index + 1}.",
                    )

            await _notify_fcm(
                request,
                client_tokens,
                title,
                body,
                {"type": "appointment_updated", "id": appt.id},
            )

            if old_datetime != appt.dateTime:
                dt_str = format_date(appt.dateTime)
                await _notify_fcm(
                    request,
                    client_tokens,
                    "Время мойки изменено",
                    f"Ваша запись перенесена на {dt_str}.",
                    {"type": "appointment_updated", "id": appt.id},
                )

    new_assigned_washers = (
        json.loads(appt.assignedWasher) if appt.assignedWasher else []
    )
    old_assigned_washers = (
        json.loads(old_assigned_washer) if old_assigned_washer else []
    )

    added_washers = [w for w in new_assigned_washers if w not in old_assigned_washers]
    removed_washers = [w for w in old_assigned_washers if w not in new_assigned_washers]

    # Batch FCM token queries to avoid N+1
    all_washer_usernames = list(set(added_washers + removed_washers))
    tokens_map: dict[str, list[str]] = {}
    if all_washer_usernames:
        tokens_res = await db.execute(
            select(FcmToken.username, FcmToken.token).where(
                FcmToken.username.in_(all_washer_usernames)
            )
        )
        for username, token in tokens_res.all():
            tokens_map.setdefault(username, []).append(token)

    dt_str = format_date(appt.dateTime)
    for washer_username in added_washers:
        encrypted_tokens = tokens_map.get(washer_username, [])
        if encrypted_tokens:
            tokens = [decrypt_token(t) for t in encrypted_tokens]
            await _notify_fcm(
                request,
                tokens,
                "Новая запись",
                f"Вы назначены на мойку {appt.carModel} {dt_str}.",
                {},
            )
    for washer_username in removed_washers:
        encrypted_tokens = tokens_map.get(washer_username, [])
        if encrypted_tokens:
            tokens = [decrypt_token(t) for t in encrypted_tokens]
            await _notify_fcm(
                request,
                tokens,
                "Назначение отменено",
                f"Вы были удалены из записи на мойку {appt.carModel} {dt_str}.",
                {},
            )

    await db.refresh(appt)
    try:
        await appointment_ws_manager.notify_appointment(db, appt, "updated")
    except Exception as e:
        logger.warning("appointment_ws_broadcast_failed", event="updated", error=str(e))

    return appt


@router.delete(
    "/{appt_id}",
    summary="Удаление записи",
)
@limiter.limit("10/minute")
async def delete_appt(
    request: Request,
    appt_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # P0: IDOR check - Only admin or the owner can delete.
    result = await db.execute(select(Appointment).where(Appointment.id == appt_id))
    appt = result.scalar_one_or_none()

    if not appt:
        raise HTTPException(404, "Запись не найдена")
    if current_user.username != appt.ownerUsername and current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "У вас нет прав на удаление этой записи."
        )

    owner = appt.ownerUsername
    car_model = appt.carModel
    date_time = appt.dateTime
    db.add(DeletedNotification(username=owner, createdAt=datetime.now()))

    # Отправка уведомления клиенту об удалении записи
    tokens_res = await db.execute(
        select(FcmToken.token).where(FcmToken.username == owner)
    )
    client_tokens = tokens_res.scalars().all()
    if client_tokens:
        await _notify_fcm(
            request,
            client_tokens,
            "Запись отменена",
            f"Ваша запись на мойку {car_model} в {date_time} была отменена.",
            {},
        )

    await db.execute(
        update(Appointment)
        .where(Appointment.id == appt_id)
        .values(isHiddenFromAdmin=True)
    )

    if current_user.role == "admin":
        await log_admin_action(
            db,
            current_user,
            action="delete_appointment",
            entity_type="appointment",
            entity_id=appt_id,
            old_values={"owner": owner, "carModel": car_model, "dateTime": date_time},
            request=request,
        )

    await db.commit()
    try:
        await appointment_ws_manager.notify_appointment(db, appt, "deleted")
    except Exception as e:
        logger.warning("appointment_ws_broadcast_failed", event="deleted", error=str(e))

    return {"ok": True}


@router.post("/{appt_id}/toggle-favorite")
@limiter.limit("10/minute")
async def toggle_favorite(
    request: Request,
    appt_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # P0: IDOR check - Only owner or admin can toggle favorite.
    result = await db.execute(
        select(Appointment.ownerUsername).where(Appointment.id == appt_id)
    )
    owner_username = result.scalar_one_or_none()
    if not owner_username:
        raise HTTPException(404, "Запись не найдена")
    if current_user.username != owner_username and current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "У вас нет прав на изменение избранного для этой записи.",
        )

    await db.execute(
        update(Appointment)
        .where(Appointment.id == appt_id)
        .values(isFavorite=1 - Appointment.isFavorite)
    )
    await db.commit()
    return {"ok": True}


@router.post(
    "/{appt_id}/assign-washer",
    response_model=AppointmentResponse,
    summary="Назначение мойщика",
)
@limiter.limit("10/minute")
async def assign_washer(
    request: Request,
    appt_id: str,
    req: AssignWasherRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(check_roles(["admin"])),
):
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
        if not target_user or target_user.role != "washer":
            raise HTTPException(400, f"Пользователь {username} не является мойщиком")

        if len(current) >= 3:
            raise HTTPException(400, "Максимум 3 мойщика")

        # Проверка на пересечение времени с другими назначенными записями
        conflict_res = await db.execute(
            select(Appointment)
            .join(AppointmentWasher)
            .where(
                AppointmentWasher.washerUsername == username,
                Appointment.status != "cancelled",
                Appointment.id != appt_id,
            )
        )
        try:
            appt_start = workload_service._ensure_datetime(appt.dateTime)
        except ValueError:
            raise HTTPException(400, "Некорректная дата записи")
        appt_duration = await workload_service.get_appointment_duration(
            db, appt.washTypeId, appt.additionalServices, appt.promoId
        )
        appt_end = appt_start + timedelta(minutes=appt_duration)
        conflict_appts = list(conflict_res.scalars().all())
        durations = await workload_service.get_appointment_durations_batch(
            db, conflict_appts + [appt]
        )
        for other in conflict_appts:
            try:
                other_start = workload_service._ensure_datetime(other.dateTime)
            except ValueError:
                continue
            other_duration = durations.get(other.id, 30)
            other_end = other_start + timedelta(minutes=other_duration)
            if appt_start < other_end and appt_end > other_start:
                raise HTTPException(
                    400, f"Мойщик {username} уже назначен на пересекающееся время"
                )

        current.append(username)

    old_assigned_washer = appt.assignedWasher
    appt.assignedWasher = json.dumps(current)

    await log_admin_action(
        db,
        current_user,
        action="assign_washer" if username in current else "unassign_washer",
        entity_type="appointment",
        entity_id=appt.id,
        old_values={"assignedWasher": old_assigned_washer},
        new_values={"assignedWasher": appt.assignedWasher, "washerUsername": username},
        request=request,
    )

    await db.commit()
    await db.refresh(appt)
    try:
        await appointment_ws_manager.notify_appointment(db, appt, "assigned")
    except Exception as e:
        logger.warning(
            "appointment_ws_broadcast_failed", event="assigned", error=str(e)
        )

    # Уведомление мойщику при назначении или снятии
    tokens_res = await db.execute(
        select(FcmToken.token).where(FcmToken.username == username)
    )
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
                box_str = (
                    f" Бокс №{appt.box_index + 1}" if appt.box_index is not None else ""
                )
                await _notify_fcm(
                    request,
                    tokens,
                    "Новая запись",
                    f"Вы назначены на мойку {appt.carModel} {dt_str}.{box_str}",
                    {"type": "appointment_updated", "id": appt.id},
                )
                logger.info("notification_sent", event="assignment", username=username)
            else:
                # Снят
                await _notify_fcm(
                    request,
                    tokens,
                    "Запись снята",
                    f"Вы были сняты с записи на мойку {appt.carModel} {dt_str}.",
                    {"type": "appointment_updated", "id": appt.id},
                )
                logger.info("notification_sent", event="removal", username=username)

    return appt


@router.get("/deleted-notification/{username}")
@limiter.limit("60/minute")
async def get_deleted_notification(
    request: Request,
    username: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # P0: IDOR check - Only the user themselves or admin can check.
    if current_user.username != username.lower() and current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "У вас нет доступа к этому уведомлению."
        )
    result = await db.execute(
        select(func.count(DeletedNotification.id)).where(
            DeletedNotification.username == username.lower()
        )
    )
    count = result.scalar()
    return {"hasNotification": count > 0}


@router.delete("/deleted-notification/{username}")
@limiter.limit("10/minute")
async def clear_deleted_notification(
    request: Request,
    username: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # P0: IDOR check - Only the user themselves or admin can clear.
    if current_user.username != username.lower() and current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "У вас нет прав на очистку этого уведомления."
        )
    await db.execute(
        delete(DeletedNotification).where(
            DeletedNotification.username == username.lower()
        )
    )
    await db.commit()
    return {"ok": True}


@router.post("/{appt_id}/clear-admin-flag")
@limiter.limit("10/minute")
async def clear_admin_flag(
    request: Request,
    appt_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # P0: IDOR check - Only admin or the owner can clear the flag.
    result = await db.execute(
        select(Appointment.ownerUsername).where(Appointment.id == appt_id)
    )
    owner_username = result.scalar_one_or_none()
    if not owner_username:
        raise HTTPException(404, "Запись не найдена")
    if current_user.username != owner_username and current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "У вас нет прав на снятие флага модификации."
        )

    await db.execute(
        update(Appointment)
        .where(Appointment.id == appt_id)
        .values(isModifiedByAdmin=0, isModifiedByWasher=0, isSeenByClient=1)
    )
    await db.commit()
    return {"ok": True}


@router.post("/{appt_id}/mark-seen")
@limiter.limit("10/minute")
async def mark_appointment_seen(
    request: Request,
    appt_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # P0: IDOR check - Only the owner or admin can mark as seen.
    result = await db.execute(
        select(Appointment.ownerUsername).where(Appointment.id == appt_id)
    )
    owner_username = result.scalar_one_or_none()
    if not owner_username:
        raise HTTPException(404, "Запись не найдена")
    if current_user.username != owner_username and current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "У вас нет прав на отметку этой записи как просмотренной.",
        )

    await db.execute(
        update(Appointment).where(Appointment.id == appt_id).values(isSeenByClient=1)
    )
    await db.commit()
    return {"ok": True}


@router.get("/{appointment_id}/qr")
@limiter.limit("60/minute")
async def get_appointment_qr(
    request: Request,
    appointment_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Appointment).where(Appointment.id == appointment_id)
    )
    appt = result.scalar_one_or_none()
    if not appt:
        raise HTTPException(404, "Запись не найдена")

    try:
        assigned_washers = (
            json.loads(appt.assignedWasher) if appt.assignedWasher else []
        )
    except json.JSONDecodeError:
        assigned_washers = []

    is_owner = current_user.username == appt.ownerUsername
    is_admin = current_user.role == "admin"
    is_washer = current_user.role == "washer"
    is_assigned_washer = is_washer and current_user.username in assigned_washers

    # Мойщик может видеть QR записей, которые попадают в его смену
    is_shift_washer = False
    if is_washer and not is_assigned_washer and appt.dateTime:
        appt_date = appt.dateTime.date()
        appt_time = appt.dateTime.time()
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
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "У вас нет доступа к QR-коду этой записи."
        )

    return {"qrData": appt.id}


@router.post("/scan-qr", response_model=AppointmentResponse)
@limiter.limit("30/minute")
async def scan_appointment_qr(
    request: Request,
    req: QrScanRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Appointment).where(Appointment.id == req.qrData).with_for_update()
    )
    appt = result.scalar_one_or_none()
    if not appt:
        raise HTTPException(404, "Запись не найдена")

    if appt.status != "scheduled":
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, f"Некорректный статус записи: {appt.status}"
        )

    try:
        assigned_washers = (
            json.loads(appt.assignedWasher) if appt.assignedWasher else []
        )
    except json.JSONDecodeError:
        assigned_washers = []

    is_admin = current_user.role == "admin"
    is_assigned_washer = (
        current_user.role == "washer" and current_user.username in assigned_washers
    )

    if not (is_admin or is_assigned_washer):
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "У вас нет прав на сканирование этой записи."
        )

    appt.status = "in_progress"
    appt.isModifiedByWasher = 1
    appt.isSeenByClient = 0

    db.add(
        LogEntry(
            username=current_user.username,
            action="qr_scan",
            details=(
                f"Сканирован QR-код записи {appt.id}, статус изменён на in_progress"
            ),
            timestamp=datetime.now(),
        )
    )

    await db.commit()
    appointments_total.labels(status="in_progress").inc()

    # Отправка FCM-уведомления клиенту (не блокируем ответ)
    if appt.ownerUsername:
        tokens_res = await db.execute(
            select(FcmToken.token).where(FcmToken.username == appt.ownerUsername)
        )
        encrypted_tokens = tokens_res.scalars().all()
        if encrypted_tokens:
            client_tokens = []
            for t in encrypted_tokens:
                try:
                    client_tokens.append(decrypt_token(t))
                except Exception:
                    pass
            if client_tokens:
                await _notify_fcm(
                    request,
                    client_tokens,
                    title="Начало обслуживания",
                    body="Мойка началась",
                    data={"type": "appointment_updated", "id": appt.id},
                )

    await db.refresh(appt)
    try:
        await appointment_ws_manager.notify_appointment(db, appt, "qr_scanned")
    except Exception as e:
        logger.warning(
            "appointment_ws_broadcast_failed", event="qr_scanned", error=str(e)
        )

    return appt


@router.post("/{appointment_id}/late", response_model=AppointmentResponse)
@limiter.limit("10/minute")
async def report_late(
    request: Request,
    appointment_id: str,
    req: LateReportRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Appointment).where(Appointment.id == appointment_id).with_for_update()
    )
    appt = result.scalar_one_or_none()
    if not appt:
        raise HTTPException(404, "Запись не найдена")
    if current_user.username != appt.ownerUsername:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Только владелец может сообщить об опоздании."
        )
    if appt.status != "scheduled":
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Можно сообщить об опоздании только для запланированной записи.",
        )

    # Idempotency: if the value is already the same, return without mutating
    # or notifying
    if appt.late_minutes == req.minutes:
        return appt

    appt.late_minutes = req.minutes

    db.add(
        LogEntry(
            username=current_user.username,
            action="report_late",
            details=(
                f"Клиент сообщил об опоздании на {req.minutes} мин для записи {appt.id}"
            ),
            timestamp=datetime.now(),
        )
    )

    await db.commit()
    await db.refresh(appt)
    try:
        await appointment_ws_manager.notify_appointment(db, appt, "late")
    except Exception as e:
        logger.warning("appointment_ws_broadcast_failed", event="late", error=str(e))

    # FCM-уведомление админам (не блокируем ответ)
    admin_tokens_res = await db.execute(
        select(FcmToken.token)
        .join(User, FcmToken.username == User.username)
        .where(User.role == "admin")
    )
    encrypted_tokens = admin_tokens_res.scalars().all()
    if encrypted_tokens:
        tokens = []
        for t in encrypted_tokens:
            try:
                tokens.append(decrypt_token(t))
            except Exception:
                pass
        if tokens:
            await _notify_fcm(
                request,
                tokens,
                title="Оповещение об опоздании",
                body=f"Клиент {appt.clientName} опаздывает на {req.minutes} мин",
                data={"type": "appointment_updated", "id": appt.id},
            )

    return appt


@router.post("/{appointment_id}/cancel-reason", response_model=AppointmentResponse)
@limiter.limit("10/minute")
async def cancel_with_reason(
    request: Request,
    appointment_id: str,
    req: CancelReasonRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Appointment).where(Appointment.id == appointment_id).with_for_update()
    )
    appt = result.scalar_one_or_none()
    if not appt:
        raise HTTPException(404, "Запись не найдена")
    if current_user.username != appt.ownerUsername:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "Только владелец может отменить запись с указанием причины.",
        )
    if appt.status not in ("scheduled", "in_progress"):
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Можно отменить только запланированную или текущую запись.",
        )

    appt.cancel_reason = req.reason
    appt.status = "cancelled"

    db.add(
        LogEntry(
            username=current_user.username,
            action="cancel_with_reason",
            details=f"Запись {appt.id} отменена. Причина: {req.reason}",
            timestamp=datetime.now(),
        )
    )

    await db.commit()
    await db.refresh(appt)
    try:
        await appointment_ws_manager.notify_appointment(db, appt, "cancelled")
    except Exception as e:
        logger.warning(
            "appointment_ws_broadcast_failed", event="cancelled", error=str(e)
        )

    appointments_total.labels(status="cancelled").inc()

    # FCM-уведомление назначенным мойщикам и админам (не блокируем ответ)
    try:
        assigned_washers = (
            json.loads(appt.assignedWasher) if appt.assignedWasher else []
        )
    except json.JSONDecodeError:
        assigned_washers = []

    admin_tokens_res = await db.execute(
        select(FcmToken.token)
        .join(User, FcmToken.username == User.username)
        .where(User.role == "admin")
    )
    washer_tokens_res = await db.execute(
        select(FcmToken.token).where(FcmToken.username.in_(assigned_washers))
    )
    encrypted_tokens = list(
        set(admin_tokens_res.scalars().all() + washer_tokens_res.scalars().all())
    )
    if encrypted_tokens:
        tokens = []
        for t in encrypted_tokens:
            try:
                tokens.append(decrypt_token(t))
            except Exception:
                pass
        if tokens:
            await _notify_fcm(
                request,
                tokens,
                title="Запись отменена",
                body=f"Запись отменена: {req.reason}",
                data={"type": "appointment_updated", "id": appt.id},
            )

    return appt


@router.get("/stats")
@limiter.limit("60/minute")
async def stats(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # P0: Assuming stats are only for admins, or all authenticated users.
    # Пока оставляем только для администраторов.
    if current_user.role != "admin":
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Доступ к статистике только для администраторов."
        )

    result = await db.execute(
        select(Appointment.status, func.count(Appointment.id)).group_by(
            Appointment.status
        )
    )
    counts = {status: count for status, count in result.all()}
    return {
        "total": sum(counts.values()),
        "scheduled": counts.get("scheduled", 0),
        "completed": counts.get("completed", 0),
    }
