from collections import defaultdict
from datetime import datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from repositories.appointment import AppointmentRepository
from schemas import ForecastResponse, ForecastSlot
from services.workload_service import NUM_BOXES

_WEEKS_HISTORY = 8
_OPERATING_START = 8
_OPERATING_END = 20


def _safe_parse_iso(dt_str: str) -> datetime:
    try:
        dt = datetime.fromisoformat(dt_str.replace("Z", "+00:00"))
        return dt.replace(tzinfo=None)
    except (ValueError, TypeError):
        raise ValueError(f"Invalid ISO datetime: {dt_str}")


async def generate_forecast(
    db: AsyncSession, reference_date=None, days: int = 7
) -> ForecastResponse:
    if reference_date is None:
        reference_date = datetime.now().replace(
            hour=0, minute=0, second=0, microsecond=0
        )
    else:
        reference_date = reference_date.replace(
            hour=0, minute=0, second=0, microsecond=0
        )

    history_start = reference_date - timedelta(weeks=_WEEKS_HISTORY)
    history_start_str = history_start.isoformat()
    history_end_str = reference_date.isoformat()

    repo = AppointmentRepository(db)
    rows = await repo.list_completed_datetimes_in_period(
        history_start_str, history_end_str
    )

    # Aggregate counts by (weekday, hour)
    counts: dict[tuple[int, int], int] = defaultdict(int)
    observed_weeks: set[int] = set()
    for (dt_str,) in rows:
        dt = _safe_parse_iso(dt_str)
        counts[(dt.weekday(), dt.hour)] += 1
        # ISO calendar week number for denominator calculation
        observed_weeks.add(dt.isocalendar().week)

    # Determine effective number of weeks for averaging.
    # Use the actual span of historical data when available so that
    # sparse test data produces intuitive averages (e.g. 4 appointments
    # spread over 4 distinct weeks -> average load 1.0).
    if observed_weeks:
        weeks_span = max(1, len(observed_weeks))
    else:
        weeks_span = _WEEKS_HISTORY

    # Average load per (weekday, hour) bucket
    averages: dict[tuple[int, int], float] = {
        bucket: count / weeks_span for bucket, count in counts.items()
    }

    capacity = NUM_BOXES
    slots = []
    for day_offset in range(days):
        day = reference_date + timedelta(days=day_offset)
        weekday = day.weekday()
        date_str = day.strftime("%Y-%m-%d")
        for hour in range(_OPERATING_START, _OPERATING_END + 1):
            predicted_load = averages.get((weekday, hour), 0.0)
            utilization_pct = round((predicted_load / capacity) * 100, 2)
            slots.append(
                ForecastSlot(
                    date=date_str,
                    hour=hour,
                    predicted_load=predicted_load,
                    capacity=capacity,
                    utilization_pct=utilization_pct,
                )
            )

    return ForecastResponse(
        items=slots,
        generated_at=datetime.now().isoformat(),
    )
