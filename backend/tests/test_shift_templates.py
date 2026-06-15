import pytest
from datetime import date, timedelta


@pytest.mark.asyncio
async def test_create_template_admin(async_client, admin_token):
    payload = {
        "name": "Admin week",
        "slots": [
            {"weekday": 1, "startTime": "09:00", "endTime": "18:00"},
            {"weekday": 3, "startTime": "10:00", "endTime": "19:00"},
        ],
    }
    response = await async_client.post(
        "/api/shift-templates/",
        json=payload,
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Admin week"
    assert len(data["slots"]) == 2
    assert data["ownerUsername"] == "admin"


@pytest.mark.asyncio
async def test_create_default_template_clears_previous(async_client, admin_token):
    payload = {"name": "First", "isDefault": True, "slots": []}
    first = await async_client.post(
        "/api/shift-templates/",
        json=payload,
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert first.json()["isDefault"] is True

    second = await async_client.post(
        "/api/shift-templates/",
        json={"name": "Second", "isDefault": True, "slots": []},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert second.status_code == 201
    assert second.json()["isDefault"] is True

    refreshed = await async_client.get(
        "/api/shift-templates/",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    templates = refreshed.json()
    first_after = next((t for t in templates if t["id"] == first.json()["id"]), None)
    assert first_after is not None
    assert first_after["isDefault"] is False


@pytest.mark.asyncio
async def test_list_templates_washer_sees_only_own(async_client, admin_token, washer_token):
    await async_client.post(
        "/api/shift-templates/",
        json={"name": "Admin template", "slots": []},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    await async_client.post(
        "/api/shift-templates/",
        json={"name": "Washer template", "slots": []},
        headers={"Authorization": f"Bearer {washer_token}"},
    )

    response = await async_client.get(
        "/api/shift-templates/",
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert all(t["ownerUsername"] == "washer_test" for t in data)
    assert any(t["name"] == "Washer template" for t in data)
    assert not any(t["name"] == "Admin template" for t in data)


@pytest.mark.asyncio
async def test_admin_can_list_all_templates(async_client, admin_token, washer_token):
    await async_client.post(
        "/api/shift-templates/",
        json={"name": "Washer template", "slots": []},
        headers={"Authorization": f"Bearer {washer_token}"},
    )

    response = await async_client.get(
        "/api/shift-templates/",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert any(t["name"] == "Washer template" for t in data)


@pytest.mark.asyncio
async def test_apply_template_admin_to_self(async_client, admin_token):
    tpl = await async_client.post(
        "/api/shift-templates/",
        json={
            "name": "Apply me",
            "slots": [
                {"weekday": 1, "startTime": "09:00", "endTime": "18:00"},
                {"weekday": 5, "startTime": "10:00", "endTime": "15:00"},
            ],
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    tpl_id = tpl.json()["id"]

    monday = date.today() + timedelta(days=-date.today().weekday(), weeks=1)
    response = await async_client.post(
        f"/api/shift-templates/{tpl_id}/apply",
        json={"weekStart": monday.isoformat()},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert response.json()["applied"] == 2

    shifts = await async_client.get(
        "/api/shifts/",
        params={"start_date": monday.isoformat(), "end_date": (monday + timedelta(days=6)).isoformat()},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert shifts.status_code == 200
    assert len(shifts.json()) == 2


@pytest.mark.asyncio
async def test_apply_template_requires_monday(async_client, admin_token):
    tpl = await async_client.post(
        "/api/shift-templates/",
        json={"name": "Bad day", "slots": []},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    tpl_id = tpl.json()["id"]

    tuesday = date.today() + timedelta(days=-date.today().weekday() + 1, weeks=1)
    response = await async_client.post(
        f"/api/shift-templates/{tpl_id}/apply",
        json={"weekStart": tuesday.isoformat()},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_washer_can_apply_to_self(async_client, washer_token):
    tpl = await async_client.post(
        "/api/shift-templates/",
        json={
            "name": "Washer own",
            "slots": [{"weekday": 2, "startTime": "08:00", "endTime": "17:00"}],
        },
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    tpl_id = tpl.json()["id"]

    monday = date.today() + timedelta(days=-date.today().weekday(), weeks=1)
    response = await async_client.post(
        f"/api/shift-templates/{tpl_id}/apply",
        json={"weekStart": monday.isoformat()},
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    assert response.status_code == 200
    assert response.json()["applied"] == 1


@pytest.mark.asyncio
async def test_washer_cannot_apply_to_other(async_client, washer_token, other_washer_token):
    tpl = await async_client.post(
        "/api/shift-templates/",
        json={"name": "Mine", "slots": [{"weekday": 1, "startTime": "09:00", "endTime": "18:00"}]},
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    tpl_id = tpl.json()["id"]

    washers = await async_client.get(
        "/api/auth/washers",
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    other_id = next(u["id"] for u in washers.json() if u["username"] == "other_washer")

    monday = date.today() + timedelta(days=-date.today().weekday(), weeks=1)
    response = await async_client.post(
        f"/api/shift-templates/{tpl_id}/apply",
        json={"weekStart": monday.isoformat(), "targetUserId": other_id},
        headers={"Authorization": f"Bearer {washer_token}"},
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_update_template(async_client, admin_token):
    tpl = await async_client.post(
        "/api/shift-templates/",
        json={"name": "Old", "slots": []},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    tpl_id = tpl.json()["id"]

    response = await async_client.put(
        f"/api/shift-templates/{tpl_id}",
        json={"name": "New", "slots": [{"weekday": 1, "startTime": "09:00", "endTime": "18:00"}]},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "New"
    assert len(data["slots"]) == 1


@pytest.mark.asyncio
async def test_delete_template(async_client, admin_token):
    tpl = await async_client.post(
        "/api/shift-templates/",
        json={"name": "To delete", "slots": []},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    tpl_id = tpl.json()["id"]

    response = await async_client.delete(
        f"/api/shift-templates/{tpl_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 204

    list_resp = await async_client.get(
        "/api/shift-templates/",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert not any(t["id"] == tpl_id for t in list_resp.json())
