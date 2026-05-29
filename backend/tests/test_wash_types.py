import pytest


class TestWashTypes:
    """Тесты CRUD типов мойки."""

    @pytest.mark.asyncio
    async def test_get_all_wash_types(self, async_client, client_token):
        response = await async_client.get(
            "/api/wash-types/",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) == 4  # seed_data создаёт w1..w4
        codes = [wt["code"] for wt in data]
        assert codes == ["express", "basic", "complex", "premium"]

    @pytest.mark.asyncio
    async def test_get_one_wash_type(self, async_client, client_token):
        response = await async_client.get(
            "/api/wash-types/w1",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["code"] == "express"
        assert data["basePrice"] == 500

    @pytest.mark.asyncio
    async def test_get_one_not_found(self, async_client, client_token):
        response = await async_client.get(
            "/api/wash-types/nonexistent",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_update_wash_type_admin(self, async_client, admin_token):
        response = await async_client.put(
            "/api/wash-types/w1",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "id": "w1",
                "code": "express",
                "name": "Экспресс-мойка обновлённая",
                "description": "Обновлённое описание",
                "basePrice": 550,
                "durationMinutes": 20,
                "sortOrder": 1,
                "includedExtraIds": [],
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Экспресс-мойка обновлённая"
        assert data["basePrice"] == 550

    @pytest.mark.asyncio
    async def test_update_wash_type_forbidden(self, async_client, client_token):
        response = await async_client.put(
            "/api/wash-types/w1",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "id": "w1",
                "code": "express",
                "name": "Hacked",
                "description": "",
                "basePrice": 0,
                "durationMinutes": 0,
                "sortOrder": 0,
                "includedExtraIds": [],
            },
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_unauthorized(self, async_client):
        response = await async_client.get("/api/wash-types/")
        assert response.status_code == 401
