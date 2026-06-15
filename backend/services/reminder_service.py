from collections import defaultdict
from datetime import datetime
from typing import List, Optional

import structlog
from sqlalchemy.ext.asyncio import AsyncSession

from models import Appointment
from repositories import (
    AppointmentRepository,
    FcmTokenRepository,
    UserRepository,
    WashTypeRepository,
)
from services.fcm_service import fcm_service

logger = structlog.get_logger()

_BATCH_SIZE = 100


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
    usernames: List[str],
    now: datetime,
    wash_types: dict,
    appointments_repo: AppointmentRepository,
    fcm_tokens_repo: FcmTokenRepository,
) -> tuple[int, int, int]:
    """Process a batch of clients and return (sent, skipped, errors)."""
    sent_count = 0
    skipped_count = 0
    error_count = 0

    # Fetch all completed appointments for this batch in one query
    appointments = await appointments_repo.list_completed_by_owners(usernames)

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

            tokens = await fcm_tokens_repo.list_tokens_by_username(username)
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

    appointments_repo = AppointmentRepository(db)
    fcm_tokens_repo = FcmTokenRepository(db)
    users_repo = UserRepository(db)
    wash_types_repo = WashTypeRepository(db)

    # Preload small reference table
    wash_types = await wash_types_repo.list_all_id_name_map()

    # Stream client usernames in batches directly from the DB
    offset = 0
    while True:
        batch = await users_repo.list_client_usernames(
            limit=_BATCH_SIZE, offset=offset
        )
        if not batch:
            break
        s, sk, e = await _process_batch(
            batch, now, wash_types, appointments_repo, fcm_tokens_repo
        )
        sent_count += s
        skipped_count += sk
        error_count += e
        offset += _BATCH_SIZE

    return {"sent": sent_count, "skipped": skipped_count, "errors": error_count}
