import json
from datetime import datetime, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_
from db_models import Appointment, WashType, Service, Promo, WashTypeIncludedExtra

NUM_BOXES = 2  # Можно вынести в конфиг или БД

class WorkloadService:
    @staticmethod
    async def get_appointment_duration(db: AsyncSession, wash_type_id: str, additional_services_json: str, promo_id: str = None) -> int:
        """
        Calculates total duration in minutes, excluding extra services already covered by the wash type.
        """
        # 1. Base wash type duration
        res_wt = await db.execute(select(WashType.durationMinutes).where(WashType.id == wash_type_id))
        base_duration = res_wt.scalar() or 30
        
        # 2. Get services already included in this wash type
        res_included = await db.execute(select(WashTypeIncludedExtra.extraServiceId).where(WashTypeIncludedExtra.washTypeId == wash_type_id))
        included_ids = {row[0] for row in res_included.all()}

        # 3. Promo duration (if it exists)
        if promo_id:
            res_promo = await db.execute(select(Promo.duration).where(Promo.id == promo_id))
            p_dur = res_promo.scalar()
            if p_dur and p_dur > 0:
                base_duration = p_dur
            
            # Also get promo included services to exclude them as well
            res_promo_inc = await db.execute(select(PromoIncludedExtra.extraServiceId).where(PromoIncludedExtra.promoId == promo_id))
            included_ids.update({row[0] for row in res_promo_inc.all()})

        # 4. Additional services duration
        total_duration = base_duration
        try:
            extra_ids = json.loads(additional_services_json)
        except:
            extra_ids = []
            
        if extra_ids:
            # Filter out services already included
            filtered_ids = [eid for eid in extra_ids if eid not in included_ids]
            if filtered_ids:
                res_extras = await db.execute(select(Service.durationMinutes).where(Service.id.in_(filtered_ids)))
                total_duration += sum(res_extras.scalars().all())

        return total_duration

    @staticmethod
    async def find_available_box(db: AsyncSession, dt_str: str, duration_minutes: int, exclude_appt_id: str = None) -> int:
        """
        Finds the first available box index (0 to NUM_BOXES-1).
        Returns -1 if no box is available.
        """
        start_dt = datetime.fromisoformat(dt_str)
        end_dt = start_dt + timedelta(minutes=duration_minutes)
        
        # We need to check all appointments that might overlap.
        # Since we don't store end_time, we have to calculate it for each appointment in the range.
        # To optimize, we can fetch all appointments for that day.
        day_start = start_dt.replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
        day_end = start_dt.replace(hour=23, minute=59, second=59, microsecond=999999).isoformat()
        
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
        
        # For each box, check if it's free during [start_dt, end_dt]
        for box_idx in range(NUM_BOXES):
            is_free = True
            for appt in day_appointments:
                if appt.box_index != box_idx:
                    continue
                
                # Calculate appt duration
                appt_duration = await WorkloadService.get_appointment_duration(
                    db, appt.washTypeId, appt.additionalServices, appt.promoId
                )
                appt_start = datetime.fromisoformat(appt.dateTime)
                appt_end = appt_start + timedelta(minutes=appt_duration)
                
                # Overlap check
                if start_dt < appt_end and end_dt > appt_start:
                    print(f"[DEBUG] Box {box_idx + 1} conflict with appt {appt.id}: {appt_start} to {appt_end}")
                    is_free = False
                    break
            
            if is_free:
                print(f"[DEBUG] Found free box {box_idx + 1} for {dt_str} ({duration_minutes} min)")
                return box_idx
        
        print(f"[DEBUG] No free box found for {dt_str} ({duration_minutes} min)")
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
            start = datetime.fromisoformat(appt.dateTime)
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
