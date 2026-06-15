from datetime import date, timedelta

import pytest

from db_models import Shift


@pytest.mark.asyncio
async def test_admin_gets_shift_load_report(async_client, admin_token, washer_token):
    today = date.today().isoformat()
    tomorrow = (date.today() + timedelta(days=1)).isoformat()

    response = await async_client.get(
        "/api/reports/shift-load/",
        params={"start_date": today, "end_date": tomorrow},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["startDate"] == today
    assert data["endDate"] == tomorrow
    assert data["targetWeeklyMinutesPerWasher"] == 2400
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
async def test_conflict_count(async_client, admin_token, washer_token, db_session):
    washers = await async_client.get(
        "/api/auth/washers",
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    washer = next(u for u in washers.json() if u["username"] == "washer_test")

    today = date.today().isoformat()
    from datetime import datetime
    now = datetime.now().isoformat()
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

    response = await async_client.get(
        "/api/reports/shift-load/",
        params={"start_date": today, "end_date": today},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert response.json()["conflictCount"] == 1
