from datetime import datetime, timedelta
from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from db_models import User, Appointment, FcmToken, WashType
from services.fcm_service import fcm_service
import structlog

logger = structlog.get_logger()


async def _get_user_fcm_tokens(db: AsyncSession, username: str) -> List[str]:
    """Fetch FCM tokens for a user."""
    result = await db.execute(select(FcmToken.token).where(FcmToken.username == username))
    return [row[0] for row in result.all() if row[0]]


async def _get_wash_type_name(db: AsyncSession, wash_type_id: str) -> str:
    """Get wash type name by ID."""
    result = await db.execute(select(WashType.name).where(WashType.id == wash_type_id))
    row = result.scalar_one_or_none()
    return row or "мойки"


async def check_and_send_reminders(db: AsyncSession) -> dict:
    """
    Analyze appointment history for each client and send FCM push
    reminders when they are overdue for a wash.
    
    Returns: {"sent": int, "skipped": int, "errors": int}
    """
    sent_count = 0
    skipped_count = 0
    error_count = 0
    
    now = datetime.now()
    
    # Get all clients
    clients_result = await db.execute(select(User).where(User.role == 'client'))
    clients = clients_result.scalars().all()
    
    for client in clients:
        try:
            # Get completed appointments for this client, sorted by date
            appts_result = await db.execute(
                select(Appointment)
                .where(
                    Appointment.ownerUsername == client.username,
                    Appointment.status == 'completed'
                )
                .order_by(Appointment.dateTime.asc())
            )
            appointments = appts_result.scalars().all()
            
            if len(appointments) < 2:
                skipped_count += 1
                continue
            
            # Calculate average interval in days
            intervals = []
            for i in range(1, len(appointments)):
                prev = datetime.fromisoformat(appointments[i - 1].dateTime)
                curr = datetime.fromisoformat(appointments[i].dateTime)
                interval = (curr - prev).total_seconds() / 86400
                if interval > 0:
                    intervals.append(interval)
            
            if not intervals:
                skipped_count += 1
                continue
            
            avg_interval = sum(intervals) / len(intervals)
            threshold_days = avg_interval + 2
            
            # Check last appointment
            last_appointment = appointments[-1]
            last_date = datetime.fromisoformat(last_appointment.dateTime)
            days_since = (now - last_date).total_seconds() / 86400
            
            if days_since <= threshold_days:
                skipped_count += 1
                continue
            
            # User is overdue — send reminder
            tokens = await _get_user_fcm_tokens(db, client.username)
            if not tokens:
                skipped_count += 1
                continue
            
            wash_type_name = await _get_wash_type_name(db, last_appointment.washTypeId)
            days_int = int(days_since)
            
            title = "Пора на мойку!"
            body = f"Прошло {days_int} дней с вашей последней {wash_type_name}. Записываемся?"
            data = {"type": "reminder", "screen": "booking"}
            
            try:
                await fcm_service.send_notification_to_tokens(
                    tokens, title=title, body=body, data=data
                )
                sent_count += 1
                logger.info(
                    "reminder_sent",
                    username=client.username,
                    days_since=days_int,
                    wash_type=wash_type_name
                )
            except Exception as e:
                error_count += 1
                logger.warning("reminder_fcm_failed", username=client.username, error=str(e))
                
        except Exception as e:
            error_count += 1
            logger.warning("reminder_processing_failed", username=client.username, error=str(e))
    
    return {"sent": sent_count, "skipped": skipped_count, "errors": error_count}
