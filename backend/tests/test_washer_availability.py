from datetime import date, timedelta

import pytest


@pytest.mark.asyncio
async def test_washer_reads_own_availability(async_client, washer_token):
    washers = await async_client.get(
        "/api/auth/washers",
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    user_id = next(u["id"] for u in washers.json() if u["username"] == "washer_test")

    start = date.today().isoformat()
    end = (date.today() + timedelta(days=6)).isoformat()
    response = await async_client.get(
        f"/api/washers/{user_id}/availability",
        params={"start_date": start, "end_date": end},
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    assert response.status_code == 200
    assert response.json() == []


@pytest.mark.asyncio
async def test_washer_cannot_read_other_washer_availability(
    async_client, washer_token, other_washer_token
):
    washers = await async_client.get(
        "/api/auth/washers",
        headers={"Authorization": f"Bearer {other_washer_token}"},
    )
    other_id = next(u["id"] for u in washers.json() if u["username"] == "other_washer")

    start = date.today().isoformat()
    end = (date.today() + timedelta(days=6)).isoformat()
    response = await async_client.get(
        f"/api/washers/{other_id}/availability",
        params={"start_date": start, "end_date": end},
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_admin_reads_any_availability(async_client, admin_token, washer_token):
    washers = await async_client.get(
        "/api/auth/washers",
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    washer_id = next(u["id"] for u in washers.json() if u["username"] == "washer_test")

    start = date.today().isoformat()
    end = (date.today() + timedelta(days=6)).isoformat()
    response = await async_client.get(
        f"/api/washers/{washer_id}/availability",
        params={"start_date": start, "end_date": end},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_update_availability_creates_records(async_client, washer_token):
    washers = await async_client.get(
        "/api/auth/washers",
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    user_id = next(u["id"] for u in washers.json() if u["username"] == "washer_test")

    d1 = date.today().isoformat()
    d2 = (date.today() + timedelta(days=1)).isoformat()
    response = await async_client.put(
        f"/api/washers/{user_id}/availability",
        json={
            "entries": [
                {"date": d1, "status": "available"},
                {"date": d2, "status": "unavailable"},
            ]
        },
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    entries = data["entries"]
    assert len(entries) == 2
    statuses = {r["date"]: r["status"] for r in entries}
    assert statuses[d1] == "available"
    assert statuses[d2] == "unavailable"
    assert all(r["userId"] == user_id for r in entries)

    start = d1
    end = d2
    listed = await async_client.get(
        f"/api/washers/{user_id}/availability",
        params={"start_date": start, "end_date": end},
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    assert listed.status_code == 200
    assert len(listed.json()) == 2


@pytest.mark.asyncio
async def test_delete_availability_removes_records(async_client, washer_token):
    washers = await async_client.get(
        "/api/auth/washers",
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    user_id = next(u["id"] for u in washers.json() if u["username"] == "washer_test")

    d1 = date.today().isoformat()
    d2 = (date.today() + timedelta(days=1)).isoformat()
    await async_client.put(
        f"/api/washers/{user_id}/availability",
        json={
            "entries": [
                {"date": d1, "status": "available"},
                {"date": d2, "status": "unavailable"},
            ]
        },
        headers={"Authorization": f"Bearer {washer_token}"},
    )

    response = await async_client.delete(
        f"/api/washers/{user_id}/availability",
        params={"start_date": d1, "end_date": d2},
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    assert response.status_code == 200
    assert response.json()["deleted"] == 2

    listed = await async_client.get(
        f"/api/washers/{user_id}/availability",
        params={"start_date": d1, "end_date": d2},
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    assert listed.json() == []


@pytest.mark.asyncio
async def test_update_availability_duplicate_dates_last_wins(
    async_client, washer_token
):
    washers = await async_client.get(
        "/api/auth/washers",
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    user_id = next(u["id"] for u in washers.json() if u["username"] == "washer_test")

    d1 = date.today().isoformat()
    response = await async_client.put(
        f"/api/washers/{user_id}/availability",
        json={
            "entries": [
                {"date": d1, "status": "available"},
                {"date": d1, "status": "unavailable"},
            ]
        },
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    entries = data["entries"]
    assert len(entries) == 1
    assert entries[0]["status"] == "unavailable"


@pytest.mark.asyncio
async def test_update_availability_invalid_date(async_client, washer_token):
    washers = await async_client.get(
        "/api/auth/washers",
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    user_id = next(u["id"] for u in washers.json() if u["username"] == "washer_test")

    response = await async_client.put(
        f"/api/washers/{user_id}/availability",
        json={"entries": [{"date": "not-a-date", "status": "available"}]},
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    assert response.status_code in (400, 422)


@pytest.mark.asyncio
async def test_update_availability_unknown_user(async_client, admin_token):
    response = await async_client.put(
        "/api/washers/999999/availability",
        json={"entries": [{"date": date.today().isoformat(), "status": "available"}]},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_client_cannot_access_availability(async_client, client_token):
    response = await async_client.get(
        "/api/washers/1/availability",
        params={
            "start_date": date.today().isoformat(),
            "end_date": date.today().isoformat(),
        },
        headers={"Authorization": f"Bearer {client_token}"},
    )
    assert response.status_code == 403
