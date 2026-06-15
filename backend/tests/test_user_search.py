from datetime import datetime

import pytest

from models import User


class TestUserSearch:
    @pytest.mark.asyncio
    async def test_search_users_admin(self, async_client, admin_token):
        """Admin can search users."""
        response = await async_client.get(
            "/api/admin/users?q=client",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert "total" in data

    @pytest.mark.asyncio
    async def test_search_users_by_role(self, async_client, admin_token):
        """Filter users by role."""
        response = await async_client.get(
            "/api/admin/users?role=washer",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        for item in data["items"]:
            assert item["role"] == "washer"

    @pytest.mark.asyncio
    async def test_search_users_by_name(self, async_client, db_session, admin_token):
        """Search by display name."""
        user = User(
            username="search_user_1",
            passwordHash="fakehash",
            role="client",
            displayName="Иван Поисков",
            phone="",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(user)
        await db_session.commit()

        response = await async_client.get(
            "/api/admin/users?q=Иван",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        names = [u["displayName"] for u in data["items"]]
        assert "Иван Поисков" in names

    @pytest.mark.asyncio
    async def test_search_users_by_phone(self, async_client, db_session, admin_token):
        """Search by phone."""
        user = User(
            username="search_user_2",
            passwordHash="fakehash",
            role="client",
            displayName="Телефонный",
            phone="+79998887766",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(user)
        await db_session.commit()

        response = await async_client.get(
            "/api/admin/users?q=79998887766",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        phones = [u["phone"] for u in data["items"]]
        assert "+79998887766" in phones

    @pytest.mark.asyncio
    async def test_search_users_pagination(self, async_client, admin_token):
        """Pagination works."""
        response = await async_client.get(
            "/api/admin/users?limit=1&offset=0",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data["items"]) <= 1
        assert data["total"] >= 0

    @pytest.mark.asyncio
    async def test_search_users_forbidden_client(self, async_client, client_token):
        """Client cannot search users."""
        response = await async_client.get(
            "/api/admin/users",
            headers={"Authorization": f"Bearer {client_token}"}
        )
        assert response.status_code == 403
