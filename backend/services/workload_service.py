import json
import hashlib
from datetime import datetime, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, text
from db_models import Appointment, WashType, Service, Promo, WashTypeIncludedExtra, PromoIncludedExtra
import structlog

logger = structlog.get_logger()

NUM_BOXES = 2  # Можно вынести в конфиг или БД

class WorkloadService:
    @staticmethod
    async def get_appointment_duration(db: AsyncSession, wash_type_id: str, additional_services_json: str, promo_id: str = None) -> int:
        """
        Calculates total duration in minutes, excluding extra services already covered by the wash type.
        """
        # 1. Базовая длительность типа мойки
        res_wt = await db.execute(select(WashType.durationMinutes).where(WashType.id == wash_type_id))
        base_duration = res_wt.scalar() or 30
        
        # 2. Получаем услуги, уже включённые в этот тип мойки
        res_included = await db.execute(select(WashTypeIncludedExtra.extraServiceId).where(WashTypeIncludedExtra.washTypeId == wash_type_id))
        included_ids = {row[0] for row in res_included.all()}

        # 3. Длительность промо (если есть)
        if promo_id:
            res_promo = await db.execute(select(Promo.duration).where(Promo.id == promo_id))
            p_dur = res_promo.scalar()
            if p_dur and p_dur > 0:
                base_duration = p_dur
            
            # Также получаем услуги, включённые в промо, чтобы исключить их
            res_promo_inc = await db.execute(select(PromoIncludedExtra.extraServiceId).where(PromoIncludedExtra.promoId == promo_id))
            included_ids.update({row[0] for row in res_promo_inc.all()})

        # 4. Длительность дополнительных услуг
        total_duration = base_duration
        try:
            extra_ids = json.loads(additional_services_json)
        except:
            extra_ids = []
            
        if extra_ids:
            # Исключаем уже включённые услуги
            filtered_ids = [eid for eid in extra_ids if eid not in included_ids]
            if filtered_ids:
                res_extras = await db.execute(select(Service.durationMinutes).where(Service.id.in_(filtered_ids)))
                total_duration += sum(res_extras.scalars().all())

        return total_duration

    @staticmethod
    def _safe_parse_iso(dt_str: str) -> datetime:
        try:
            return datetime.fromisoformat(dt_str.replace('Z', '+00:00'))
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
        lock_input = day_start.encode()
        lock_id = int.from_bytes(hashlib.md5(lock_input).digest()[:4], 'little')
        await db.execute(text(f"SELECT pg_advisory_xact_lock({lock_id})"))

        query = select(Appointment).where(
            and_(
                Appointment.dateTime >= day_start,
                Appointment.dateTime <= day_end,
                Appointment.status != 'cancelled'
            )
        )
        if exclude_appt_id:
            query = query.where(Appointment.id != exclude_appt_id)
            
        res = await db.execute(query)
        day_appointments = res.scalars().all()
        
        box_occupancy = [False] * NUM_BOXES
        
        # Для каждого бокса проверяем, свободен ли он в интервале [start_dt, end_dt]
        for box_idx in range(NUM_BOXES):
            is_free = True
            for appt in day_appointments:
                if appt.box_index != box_idx:
                    continue
                
                # Вычисляем длительность записи
                appt_duration = await WorkloadService.get_appointment_duration(
                    db, appt.washTypeId, appt.additionalServices, appt.promoId
                )
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
        date_str: 'YYYY-MM-DD'
        """
        day_start = f"{date_str}T00:00:00"
        day_end = f"{date_str}T23:59:59"
        
        res = await db.execute(
            select(Appointment).where(
                and_(
                    Appointment.dateTime >= day_start,
                    Appointment.dateTime <= day_end,
                    Appointment.status != 'cancelled'
                )
            )
        )
        appts = res.scalars().all()
        
        busy_by_box = [[] for _ in range(NUM_BOXES)]
        
        for appt in appts:
            duration = await WorkloadService.get_appointment_duration(
                db, appt.washTypeId, appt.additionalServices, appt.promoId
            )
            start = WorkloadService._safe_parse_iso(appt.dateTime)
            end = start + timedelta(minutes=duration)
            
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
