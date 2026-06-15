from collections import defaultdict
from datetime import datetime
from typing import List, Optional

import structlog
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Appointment, FcmToken, User, WashType
from services.fcm_service import fcm_service

logger = structlog.get_logger()

_BATCH_SIZE = 100


async def _get_user_fcm_tokens(db: AsyncSession, username: str) -> List[str]:
    """Fetch FCM tokens for a user."""
    result = await db.execute(select(FcmToken.token).where(FcmToken.username == username))
    return [row[0] for row in result.all() if row[0]]


async def _get_wash_type_name(db: AsyncSession, wash_type_id: str) -> str:
    """Get wash type name by ID."""
    result = await db.execute(select(WashType.name).where(WashType.id == wash_type_id))
    row = result.scalar_one_or_none()
    return row or "мойки"


def _avg_interval_days(appointments: List[Appointment]) -> Optional[float]:
    """Calculate average positive interval in days between sorted appointments."""
    if len(appointments) < 2:
        return None
    intervals: List[float] = []
    for i in range(1, len(appointments)):
        prev = datetime.fromisoformat(appointments[i - 1].dateTime)
        curr = datetime.fromisoformat(appointments[i].dateTime)
        interval = (curr - prev).total_seconds() / 86400
        if interval > 0:
            intervals.append(interval)
    if not intervals:
        return None
    return sum(intervals) / len(intervals)


async def _process_batch(
    db: AsyncSession,
    usernames: List[str],
    now: datetime,
    wash_types: dict,
) -> tuple[int, int, int]:
    """Process a batch of clients and return (sent, skipped, errors)."""
    sent_count = 0
    skipped_count = 0
    error_count = 0

    # Fetch all completed appointments for this batch in one query
    appts_result = await db.execute(
        select(Appointment)
        .where(
            Appointment.ownerUsername.in_(usernames),
            Appointment.status == 'completed',
        )
        .order_by(Appointment.dateTime.asc())
    )
    appointments = appts_result.scalars().all()

    by_user: dict[str, List[Appointment]] = defaultdict(list)
    for appt in appointments:
        by_user[appt.ownerUsername].append(appt)

    for username in usernames:
        try:
            user_appts = by_user.get(username, [])
            if len(user_appts) < 2:
                skipped_count += 1
                continue

            avg_interval = _avg_interval_days(user_appts)
            if avg_interval is None:
                skipped_count += 1
                continue

            threshold_days = avg_interval + 2
            last_appointment = user_appts[-1]
            last_date = datetime.fromisoformat(last_appointment.dateTime)
            days_since = (now - last_date).total_seconds() / 86400

            if days_since <= threshold_days:
                skipped_count += 1
                continue

            tokens = await _get_user_fcm_tokens(db, username)
            if not tokens:
                skipped_count += 1
                continue

            wash_type_name = wash_types.get(last_appointment.washTypeId, "мойки")
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
                    username=username,
                    days_since=days_int,
                    wash_type=wash_type_name,
                )
            except Exception as e:
                error_count += 1
                logger.warning("reminder_fcm_failed", username=username, error=str(e))

        except Exception as e:
            error_count += 1
            logger.warning("reminder_processing_failed", username=username, error=str(e))

    return sent_count, skipped_count, error_count


async def check_and_send_reminders(db: AsyncSession) -> dict:
    """
    Analyze appointment history for each client and send FCM push
    reminders when they are overdue for a wash.

    Processes clients in fixed-size batches to avoid unbounded memory usage
    and N+1 query patterns.

    Returns: {"sent": int, "skipped": int, "errors": int}
    """
    sent_count = 0
    skipped_count = 0
    error_count = 0

    now = datetime.now()

    # Preload small reference table
    wash_types_result = await db.execute(select(WashType.id, WashType.name))
    wash_types = {row[0]: row[1] for row in wash_types_result.all()}

    # Stream client usernames in batches directly from the DB
    offset = 0
    while True:
        clients_result = await db.execute(
            select(User.username)
            .where(User.role == 'client')
            .order_by(User.id)
            .limit(_BATCH_SIZE)
            .offset(offset)
        )
        batch = [row[0] for row in clients_result.all() if row[0]]
        if not batch:
            break
        s, sk, e = await _process_batch(db, batch, now, wash_types)
        sent_count += s
        skipped_count += sk
        error_count += e
        offset += _BATCH_SIZE

    return {"sent": sent_count, "skipped": skipped_count, "errors": error_count}
