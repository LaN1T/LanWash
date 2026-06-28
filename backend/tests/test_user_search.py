from datetime import datetime

import pytest

from models import Car, User


class TestUserSearch:
    @pytest.mark.asyncio
    async def test_search_users_admin(self, async_client, admin_token):
        """Admin can search users."""
        response = await async_client.get(
            "/api/admin/users?q=client",
            headers={"Authorization": f"Bearer {admin_token}"},
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
            headers={"Authorization": f"Bearer {admin_token}"},
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
            createdAt=datetime.now(),
        )
        db_session.add(user)
        await db_session.commit()

        response = await async_client.get(
            "/api/admin/users?q=Иван",
            headers={"Authorization": f"Bearer {admin_token}"},
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
            createdAt=datetime.now(),
        )
        db_session.add(user)
        await db_session.commit()

        response = await async_client.get(
            "/api/admin/users?q=79998887766",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        phones = [u["phone"] for u in data["items"]]
        assert "+79998887766" in phones

    @pytest.mark.asyncio
    async def test_search_users_by_primary_car_number(
        self, async_client, db_session, admin_token
    ):
        """Search by primary car number digits."""
        user = User(
            username="search_user_3",
            passwordHash="fakehash",
            role="client",
            displayName="Автомобильный",
            phone="",
            carNumber="А 123 БВ 77",
            createdAt=datetime.now(),
        )
        db_session.add(user)
        await db_session.commit()

        response = await async_client.get(
            "/api/admin/users?q=12377",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        car_numbers = [u["carNumber"] for u in data["items"]]
        assert "А 123 БВ 77" in car_numbers

    @pytest.mark.asyncio
    async def test_search_users_by_car_model_and_number(
        self, async_client, db_session, admin_token
    ):
        """Search clients by a linked car's model or number digits."""
        user = User(
            username="search_user_car",
            passwordHash="fakehash",
            role="client",
            displayName="Автомобильный 2",
            phone="",
            createdAt=datetime.now(),
        )
        db_session.add(user)
        await db_session.commit()

        car = Car(
            userId=user.id,
            brand="Toyota",
            model="Camry",
            number="О 777 ОО 99",
            isPrimary=False,
        )
        db_session.add(car)
        await db_session.commit()

        response = await async_client.get(
            "/api/admin/users?q=Camry",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        user_ids = [u["id"] for u in data["items"]]
        assert user.id in user_ids

        response = await async_client.get(
            "/api/admin/users?q=777",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        user_ids = [u["id"] for u in data["items"]]
        assert user.id in user_ids

    @pytest.mark.asyncio
    async def test_search_users_pagination(self, async_client, admin_token):
        """Pagination works."""
        response = await async_client.get(
            "/api/admin/users?limit=1&offset=0",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data["items"]) <= 1
        assert data["total"] >= 0

    @pytest.mark.asyncio
    async def test_search_users_forbidden_client(self, async_client, client_token):
        """Client cannot search users."""
        response = await async_client.get(
            "/api/admin/users", headers={"Authorization": f"Bearer {client_token}"}
        )
        assert response.status_code == 403


class TestUserSearchDataSync:
    def test_user_creation_populates_search_data(self):
        """Creating a User syncs phone, email and carNumber into searchData."""
        user = User(
            username="search_data_user",
            passwordHash="fakehash",
            role="client",
            displayName="Тест",
            phone="+7 (999) 123-45-67",
            email="Test@Example.COM ",
            carNumber="А 123 БВ 77",
        )

        assert user.searchData == {
            "phone": "79991234567",
            "email": "test@example.com",
            "car_number": "12377",
        }
