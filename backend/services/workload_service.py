import hashlib
import json
import os
from datetime import datetime, timedelta

import structlog
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from models import Appointment
from repositories.appointment import AppointmentRepository
from repositories.promo import PromoRepository
from repositories.promo_included_extra import PromoIncludedExtraRepository
from repositories.service import ServiceRepository
from repositories.wash_type import WashTypeRepository
from repositories.wash_type_included_extra import WashTypeIncludedExtraRepository

logger = structlog.get_logger()

# Advisory locks can block the event loop under concurrent load testing.
_DISABLE_ADVISORY_LOCK = os.getenv("DISABLE_ADVISORY_LOCK") == "true" or os.getenv("ENVIRONMENT") == "testing"

NUM_BOXES = 2  # Можно вынести в конфиг или БД


class WorkloadService:
    @staticmethod
    async def get_appointment_duration(db: AsyncSession, wash_type_id: str, additional_services_json: str, promo_id: str = None) -> int:
        """
        Calculates total duration in minutes, excluding extra services already covered by the wash type.
        """
        wash_types = WashTypeRepository(db)
        wash_type_extras = WashTypeIncludedExtraRepository(db)
        promos = PromoRepository(db)
        promo_extras = PromoIncludedExtraRepository(db)
        services = ServiceRepository(db)

        # 1. Базовая длительность типа мойки
        wt_durations = await wash_types.get_durations([wash_type_id])
        base_duration = wt_durations.get(wash_type_id, 30)

        # 2. Получаем услуги, уже включённые в этот тип мойки
        wt_included_raw = await wash_type_extras.list_extras_for_wash_types([wash_type_id])
        included_ids = set(wt_included_raw.get(wash_type_id, []))

        # 3. Длительность промо (если есть)
        if promo_id:
            promo_durations = await promos.get_durations([promo_id])
            p_dur = promo_durations.get(promo_id)
            if p_dur and p_dur > 0:
                base_duration = p_dur

            # Также получаем услуги, включённые в промо, чтобы исключить их
            promo_included_raw = await promo_extras.list_extras_for_promos([promo_id])
            included_ids.update(promo_included_raw.get(promo_id, []))

        # 4. Длительность дополнительных услуг
        total_duration = base_duration
        try:
            extra_ids = json.loads(additional_services_json)
        except Exception:
            extra_ids = []

        if extra_ids:
            # Исключаем уже включённые услуги
            filtered_ids = [eid for eid in extra_ids if eid not in included_ids]
            if filtered_ids:
                svc_durations = await services.get_durations(filtered_ids)
                total_duration += sum(svc_durations.get(eid, 0) for eid in filtered_ids)

        return total_duration

    @staticmethod
    async def get_appointment_durations_batch(
        db: AsyncSession, appointments: list[Appointment]
    ) -> dict[str, int]:
        """Batch-compute durations for multiple appointments to avoid N+1 queries."""
        if not appointments:
            return {}

        wash_types = WashTypeRepository(db)
        wash_type_extras = WashTypeIncludedExtraRepository(db)
        promos = PromoRepository(db)
        promo_extras = PromoIncludedExtraRepository(db)
        services = ServiceRepository(db)

        wash_type_ids = {a.washTypeId for a in appointments}
        promo_ids = {a.promoId for a in appointments if a.promoId}
        all_service_ids: set = set()
        for a in appointments:
            try:
                all_service_ids.update(json.loads(a.additionalServices))
            except Exception:
                pass

        # Wash type durations
        wt_durations = await wash_types.get_durations(list(wash_type_ids))

        # Wash type included extras
        wt_included_raw = await wash_type_extras.list_extras_for_wash_types(list(wash_type_ids))
        wt_included: dict[str, set] = {
            wt_id: set(extra_ids) for wt_id, extra_ids in wt_included_raw.items()
        }

        # Promo durations and included extras
        promo_durations = await promos.get_durations(list(promo_ids))
        promo_included_raw = await promo_extras.list_extras_for_promos(list(promo_ids))
        promo_included: dict[str, set] = {
            promo_id: set(extra_ids) for promo_id, extra_ids in promo_included_raw.items()
        }

        # Service durations
        svc_durations = await services.get_durations(list(all_service_ids))

        result = {}
        for a in appointments:
            base = wt_durations.get(a.washTypeId, 30)
            included = set(wt_included.get(a.washTypeId, []))
            if a.promoId and a.promoId in promo_durations:
                p_dur = promo_durations[a.promoId]
                if p_dur and p_dur > 0:
                    base = p_dur
                included.update(promo_included.get(a.promoId, []))
            try:
                extra_ids = json.loads(a.additionalServices)
            except Exception:
                extra_ids = []
            filtered = [eid for eid in extra_ids if eid not in included]
            total = base + sum(svc_durations.get(eid, 0) for eid in filtered)
            result[a.id] = total

        return result

    @staticmethod
    def _safe_parse_iso(dt_str: str) -> datetime:
        try:
            dt = datetime.fromisoformat(dt_str.replace('Z', '+00:00'))
            return dt.replace(tzinfo=None)
        except (ValueError, TypeError):
            raise ValueError(f"Invalid ISO datetime: {dt_str}")

    @staticmethod
    async def find_available_box(db: AsyncSession, dt_str: str, duration_minutes: int, exclude_appt_id: str = None) -> int:
        """
        Finds the first available box index (0 to NUM_BOXES-1).
        Returns -1 if no box is available.
        """
        start_dt = WorkloadService._safe_parse_iso(dt_str)
        end_dt = start_dt + timedelta(minutes=duration_minutes)

        # Проверяем все записи, которые могут пересекаться.
        # Так как end_time не хранится, вычисляем его для каждой записи.
        # Для оптимизации загружаем все записи за этот день.
        day_start = start_dt.replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
        day_end = start_dt.replace(hour=23, minute=59, second=59, microsecond=999999).isoformat()

        # Advisory lock на уровне дня для предотвращения race condition при бронировании
        # Работает только на PostgreSQL; на SQLite пропускаем
        if not _DISABLE_ADVISORY_LOCK:
            # Проверяем движок БД — advisory lock есть только в PostgreSQL
            dialect_name = getattr(getattr(db, 'bind', None), 'dialect', None)
            if dialect_name is None:
                # AsyncSession — достаём sync_session.bind
                sync_bind = getattr(getattr(db, 'sync_session', None), 'bind', None)
                dialect_name = getattr(sync_bind, 'dialect', None)
            is_postgres = getattr(dialect_name, 'name', '') == 'postgresql'
            if is_postgres:
                lock_input = day_start.encode()
                lock_id = int.from_bytes(hashlib.md5(lock_input).digest()[:4], 'little')
                await db.execute(text("SELECT pg_advisory_xact_lock(:lock_id)").bindparams(lock_id=lock_id))

        appointments = AppointmentRepository(db)
        day_appointments = await appointments.list_for_day(day_start, day_end, exclude_appt_id)

        # --- Batch preload all duration data to avoid N+1 queries ---
        wash_types = WashTypeRepository(db)
        wash_type_extras = WashTypeIncludedExtraRepository(db)
        promos = PromoRepository(db)
        promo_extras = PromoIncludedExtraRepository(db)
        services = ServiceRepository(db)

        wash_type_ids = {a.washTypeId for a in day_appointments}
        promo_ids = {a.promoId for a in day_appointments if a.promoId}
        all_service_ids = set()
        for a in day_appointments:
            try:
                all_service_ids.update(json.loads(a.additionalServices))
            except Exception:
                pass

        # Wash type durations
        wt_durations = await wash_types.get_durations(list(wash_type_ids))

        # Wash type included extras
        wt_included_raw = await wash_type_extras.list_extras_for_wash_types(list(wash_type_ids))
        wt_included: dict[str, set] = {
            wt_id: set(extra_ids) for wt_id, extra_ids in wt_included_raw.items()
        }

        # Promo durations and included extras
        promo_durations = await promos.get_durations(list(promo_ids))
        promo_included_raw = await promo_extras.list_extras_for_promos(list(promo_ids))
        promo_included: dict[str, set] = {
            promo_id: set(extra_ids) for promo_id, extra_ids in promo_included_raw.items()
        }

        # Service durations
        svc_durations = await services.get_durations(list(all_service_ids))

        def _compute_duration(appt) -> int:
            base = wt_durations.get(appt.washTypeId, 30)
            included = set(wt_included.get(appt.washTypeId, []))
            if appt.promoId and appt.promoId in promo_durations:
                p_dur = promo_durations[appt.promoId]
                if p_dur and p_dur > 0:
                    base = p_dur
                included.update(promo_included.get(appt.promoId, []))
            try:
                extra_ids = json.loads(appt.additionalServices)
            except Exception:
                extra_ids = []
            filtered = [eid for eid in extra_ids if eid not in included]
            total = base + sum(svc_durations.get(eid, 0) for eid in filtered)
            return total
        # --- End batch preload ---

        # Для каждого бокса проверяем, свободен ли он в интервале [start_dt, end_dt]
        for box_idx in range(NUM_BOXES):
            is_free = True
            for appt in day_appointments:
                if appt.box_index != box_idx:
                    continue

                # Вычисляем длительность записи (локально, без N+1 запросов)
                appt_duration = _compute_duration(appt)
                appt_start = WorkloadService._safe_parse_iso(appt.dateTime)
                appt_end = appt_start + timedelta(minutes=appt_duration)

                # Проверка пересечения
                if start_dt < appt_end and end_dt > appt_start:
                    logger.debug("box_conflict", box=box_idx + 1, appt_id=appt.id, appt_start=appt_start.isoformat(), appt_end=appt_end.isoformat())
                    is_free = False
                    break

            if is_free:
                logger.debug("box_found", box=box_idx + 1, dt_str=dt_str, duration=duration_minutes)
                return box_idx

        logger.debug("no_free_box", dt_str=dt_str, duration=duration_minutes)
        return -1

    @staticmethod
    async def get_busy_slots(db: AsyncSession, date_str: str) -> dict:
        """
        Returns busy periods for each box for a given date.
        Optimized: loads all data in bulk to avoid N+1 queries.
        date_str: 'YYYY-MM-DD'
        """
        day_start = f"{date_str}T00:00:00"
        day_end = f"{date_str}T23:59:59"

        appointments = AppointmentRepository(db)
        appts = await appointments.list_for_day(day_start, day_end)

        if not appts:
            return {"num_boxes": NUM_BOXES, "busy_slots": [[] for _ in range(NUM_BOXES)]}

        wash_types = WashTypeRepository(db)
        wash_type_extras = WashTypeIncludedExtraRepository(db)
        promos = PromoRepository(db)
        promo_extras = PromoIncludedExtraRepository(db)
        services = ServiceRepository(db)

        # Collect all IDs needed
        wash_type_ids = {a.washTypeId for a in appts}
        promo_ids = {a.promoId for a in appts if a.promoId}
        all_service_ids = set()
        for a in appts:
            try:
                all_service_ids.update(json.loads(a.additionalServices))
            except Exception:
                pass

        # Bulk load wash types
        wt_durations = await wash_types.get_durations(list(wash_type_ids))

        # Bulk load wash type included extras
        wt_included_raw = await wash_type_extras.list_extras_for_wash_types(list(wash_type_ids))
        wt_included: dict[str, set] = {
            wt_id: set(extra_ids) for wt_id, extra_ids in wt_included_raw.items()
        }

        # Bulk load promo durations
        promo_durations = await promos.get_durations(list(promo_ids))
        promo_included_raw = await promo_extras.list_extras_for_promos(list(promo_ids))
        promo_included: dict[str, set] = {
            promo_id: set(extra_ids) for promo_id, extra_ids in promo_included_raw.items()
        }

        # Bulk load all services durations (small table, just load all)
        svc_durations = await services.get_durations(list(all_service_ids))

        busy_by_box = [[] for _ in range(NUM_BOXES)]

        for appt in appts:
            # Compute duration without DB calls
            base_duration = wt_durations.get(appt.washTypeId, 30)
            included = set(wt_included.get(appt.washTypeId, []))

            if appt.promoId and appt.promoId in promo_durations:
                p_dur = promo_durations[appt.promoId]
                if p_dur and p_dur > 0:
                    base_duration = p_dur
                included.update(promo_included.get(appt.promoId, []))

            total_duration = base_duration
            try:
                extra_ids = json.loads(appt.additionalServices) if appt.additionalServices else []
            except Exception:
                extra_ids = []

            for eid in extra_ids:
                if eid not in included:
                    total_duration += svc_durations.get(eid, 0)

            start = WorkloadService._safe_parse_iso(appt.dateTime)
            end = start + timedelta(minutes=total_duration)

            if 0 <= appt.box_index < NUM_BOXES:
                busy_by_box[appt.box_index].append({
                    "start": start.isoformat(),
                    "end": end.isoformat()
                })

        return {
            "num_boxes": NUM_BOXES,
            "busy_slots": busy_by_box
        }


workload_service = WorkloadService()
