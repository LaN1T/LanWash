from datetime import date, datetime, timedelta

import pytest

from models import Shift, WasherAvailability
from services.reports_service import SHIFT_LOAD_TARGET_WEEKLY_MINUTES


@pytest.mark.asyncio
async def test_admin_gets_shift_load_report(async_client, admin_token):
    today_date = date.today()
    tomorrow_date = today_date + timedelta(days=1)
    today = today_date.isoformat()
    tomorrow = tomorrow_date.isoformat()

    response = await async_client.get(
        "/api/reports/shift-load/",
        params={"start_date": today, "end_date": tomorrow},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["startDate"] == today
    assert data["endDate"] == tomorrow
    assert data["targetWeeklyMinutesPerWasher"] == SHIFT_LOAD_TARGET_WEEKLY_MINUTES
    assert "dailyHours" in data
    assert "washerStats" in data
    assert "statusCounts" in data
    assert "conflictCount" in data
    assert "availabilityCoverage" in data


@pytest.mark.asyncio
async def test_washer_cannot_access_shift_load(async_client, washer_token):
    today = date.today().isoformat()
    tomorrow = (date.today() + timedelta(days=1)).isoformat()
    response = await async_client.get(
        "/api/reports/shift-load/",
        params={"start_date": today, "end_date": tomorrow},
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_invalid_date_returns_400(async_client, admin_token):
    response = await async_client.get(
        "/api/reports/shift-load/",
        params={"start_date": "bad", "end_date": "2026-06-14"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_start_date_after_end_date_returns_400(async_client, admin_token):
    response = await async_client.get(
        "/api/reports/shift-load/",
        params={"start_date": "2026-06-15", "end_date": "2026-06-10"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_empty_report(async_client, admin_token):
    start = (date.today() + timedelta(days=365)).isoformat()
    end = (date.today() + timedelta(days=366)).isoformat()

    response = await async_client.get(
        "/api/reports/shift-load/",
        params={"start_date": start, "end_date": end},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["startDate"] == start
    assert data["endDate"] == end
    assert len(data["dailyHours"]) == 2
    assert all(
        entry["confirmedMinutes"] == 0 and entry["pendingMinutes"] == 0
        for entry in data["dailyHours"]
    )
    for washer in data["washerStats"]:
        assert washer["confirmedMinutes"] == 0
        assert washer["pendingMinutes"] == 0
        assert washer["rejectedMinutes"] == 0
    status = data["statusCounts"]
    assert status["confirmed"] == 0
    assert status["pending"] == 0
    assert status["rejected"] == 0
    assert data["conflictCount"] == 0
    coverage = data["availabilityCoverage"]
    assert coverage["availableDays"] == 0
    assert coverage["unavailableDays"] == 0
    assert coverage["unknownDays"] == len(data["washerStats"]) * len(data["dailyHours"])


@pytest.mark.asyncio
async def test_conflict_count(async_client, admin_token, washer_token, db_session):
    washers = await async_client.get(
        "/api/auth/washers",
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    washer = next(u for u in washers.json() if u["username"] == "washer_test")

    today = date.today()
    now = datetime.now()
    db_session.add_all(
        [
            Shift(
                userId=washer["id"],
                date=today,
                startTime="10:00",
                endTime="14:00",
                status="confirmed",
                createdBy="admin",
                createdAt=now,
                updatedAt=now,
            ),
            Shift(
                userId=washer["id"],
                date=today,
                startTime="12:00",
                endTime="16:00",
                status="confirmed",
                createdBy="admin",
                createdAt=now,
                updatedAt=now,
            ),
        ]
    )
    await db_session.commit()

    today_str = today.isoformat()
    response = await async_client.get(
        "/api/reports/shift-load/",
        params={"start_date": today_str, "end_date": today_str},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert response.json()["conflictCount"] == 1


@pytest.mark.asyncio
async def test_availability_coverage(
    async_client, admin_token, washer_token, db_session
):
    washers = await async_client.get(
        "/api/auth/washers",
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    washer = next(u for u in washers.json() if u["username"] == "washer_test")

    today = date.today()
    tomorrow = today + timedelta(days=1)
    now = datetime.now()
    db_session.add_all(
        [
            WasherAvailability(
                userId=washer["id"], date=today, status="available", updatedAt=now
            ),
            WasherAvailability(
                userId=washer["id"], date=tomorrow, status="unavailable", updatedAt=now
            ),
        ]
    )
    await db_session.commit()

    today_str = today.isoformat()
    tomorrow_str = tomorrow.isoformat()
    response = await async_client.get(
        "/api/reports/shift-load/",
        params={"start_date": today_str, "end_date": tomorrow_str},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    coverage = data["availabilityCoverage"]
    total_washers = len(data["washerStats"])
    assert coverage["availableDays"] == 1
    assert coverage["unavailableDays"] == 1
    assert coverage["unknownDays"] == total_washers * 2 - 1 - 1
