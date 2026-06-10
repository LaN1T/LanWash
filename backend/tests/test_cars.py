from datetime import datetime

import pytest

from db_models import Car, User
from services.auth_service import get_password_hash


class TestCars:
    @pytest.mark.asyncio
    async def test_create_car(self, async_client, client_token):
        response = await async_client.post(
            "/api/cars/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"brand": "BMW", "model": "X5", "number": "А123БВ777"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["brand"] == "BMW"
        assert data["model"] == "X5"
        assert data["number"] == "А123БВ777"
        assert data["isPrimary"] is True  # First car becomes primary

    @pytest.mark.asyncio
    async def test_get_cars(self, async_client, client_token):
        # Create two cars
        await async_client.post(
            "/api/cars/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"brand": "BMW", "model": "X5", "number": "А123БВ777"},
        )
        await async_client.post(
            "/api/cars/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"brand": "Audi", "model": "A6", "number": "В456КМ777"},
        )

        response = await async_client.get(
            "/api/cars/",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2

    @pytest.mark.asyncio
    async def test_update_car(self, async_client, client_token):
        create_res = await async_client.post(
            "/api/cars/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"brand": "BMW", "model": "X5", "number": "А123БВ777"},
        )
        car_id = create_res.json()["id"]

        response = await async_client.put(
            f"/api/cars/{car_id}",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"brand": "Mercedes", "model": "E-Class", "number": "Е999ЕЕ777"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["brand"] == "Mercedes"
        assert data["number"] == "Е999ЕЕ777"

    @pytest.mark.asyncio
    async def test_primary_car_auto_unset(self, async_client, client_token):
        # Create first car (auto primary)
        r1 = await async_client.post(
            "/api/cars/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"brand": "BMW", "model": "X5", "number": "А123БВ777"},
        )
        first_id = r1.json()["id"]
        assert r1.json()["isPrimary"] is True

        # Create second car with isPrimary=true
        r2 = await async_client.post(
            "/api/cars/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"brand": "Audi", "model": "A6", "number": "В456КМ777", "isPrimary": True},
        )
        second_id = r2.json()["id"]
        assert r2.json()["isPrimary"] is True

        # First car should no longer be primary
        response = await async_client.get(
            "/api/cars/",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        cars = {c["id"]: c for c in response.json()}
        assert cars[first_id]["isPrimary"] is False
        assert cars[second_id]["isPrimary"] is True

    @pytest.mark.asyncio
    async def test_delete_primary_makes_oldest_primary(self, async_client, client_token):
        # Create three cars
        r1 = await async_client.post(
            "/api/cars/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"brand": "BMW", "model": "X5", "number": "А111БВ777"},
        )
        r2 = await async_client.post(
            "/api/cars/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"brand": "Audi", "model": "A6", "number": "А222БВ777"},
        )
        r3 = await async_client.post(
            "/api/cars/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"brand": "Mercedes", "model": "E", "number": "А333БВ777", "isPrimary": True},
        )
        third_id = r3.json()["id"]
        first_id = r1.json()["id"]

        # Delete the primary car (third)
        response = await async_client.delete(
            f"/api/cars/{third_id}",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200

        # Oldest remaining (first) should now be primary
        response = await async_client.get(
            "/api/cars/",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        cars = {c["id"]: c for c in response.json()}
        assert cars[first_id]["isPrimary"] is True
        assert len(cars) == 2

    @pytest.mark.asyncio
    async def test_delete_last_car(self, async_client, client_token):
        # Create one car
        r1 = await async_client.post(
            "/api/cars/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"brand": "BMW", "model": "X5", "number": "А111БВ777"},
        )
        car_id = r1.json()["id"]
        assert r1.json()["isPrimary"] is True

        # Delete the only car
        response = await async_client.delete(
            f"/api/cars/{car_id}",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200

        # No cars should remain
        response = await async_client.get(
            "/api/cars/",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 200
        assert response.json() == []

    @pytest.mark.asyncio
    async def test_unset_primary_on_only_car(self, async_client, client_token):
        # Create one car (auto primary)
        r1 = await async_client.post(
            "/api/cars/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"brand": "BMW", "model": "X5", "number": "А111БВ777"},
        )
        car_id = r1.json()["id"]
        assert r1.json()["isPrimary"] is True

        # Unset primary on the only car
        response = await async_client.put(
            f"/api/cars/{car_id}",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"brand": "BMW", "model": "X5", "number": "А111БВ777", "isPrimary": False},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["isPrimary"] is False

    @pytest.mark.asyncio
    async def test_cannot_access_other_users_car(self, async_client, client_token, db_session):
        # Create another user
        from services.auth_service import get_password_hash
        other = User(
            username="other_client",
            passwordHash=get_password_hash("TestPass123!"),
            role="client",
            displayName="Other Client",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(other)
        await db_session.commit()

        # Add a car for the other user directly
        other_car = Car(userId=other.id, brand="Toyota", model="Camry", number="О777ОО777", isPrimary=True)
        db_session.add(other_car)
        await db_session.commit()

        # Try to update other user's car
        response = await async_client.put(
            f"/api/cars/{other_car.id}",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"brand": "Hacked", "model": "HackedModel"},
        )
        assert response.status_code == 403

        # Try to delete other user's car
        response = await async_client.delete(
            f"/api/cars/{other_car.id}",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_create_appointment_with_car_id(self, async_client, client_token):
        # Create a car
        car_res = await async_client.post(
            "/api/cars/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={"brand": "BMW", "model": "X5", "number": "А123БВ777"},
        )
        car_id = car_res.json()["id"]

        # Create appointment using carId
        response = await async_client.post(
            "/api/appointments/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "id": "test-appt-car",
                "clientName": "Test",
                "carModel": "",
                "carNumber": "",
                "carId": car_id,
                "dateTime": "2026-06-10T10:00:00",
                "washTypeId": "w1",
                "additionalServices": "[]",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["carModel"] == "BMW X5"
        assert data["carNumber"] == "А123БВ777"

    @pytest.mark.asyncio
    async def test_create_appointment_with_invalid_car_id(self, async_client, client_token):
        response = await async_client.post(
            "/api/appointments/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "id": "test-appt-bad-car",
                "clientName": "Test",
                "carModel": "",
                "carNumber": "",
                "carId": 99999,
                "dateTime": "2026-06-10T10:00:00",
                "washTypeId": "w1",
                "additionalServices": "[]",
            },
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_admin_create_appointment_with_client_car(self, async_client, admin_token, db_session):
        # Create a client user directly in DB
        from services.auth_service import get_password_hash
        client_user = User(
            username="target_client",
            passwordHash=get_password_hash("TestPass123!"),
            role="client",
            displayName="Target Client",
            createdAt=datetime.now().isoformat(),
        )
        db_session.add(client_user)
        await db_session.commit()

        # Create a car for the client directly
        client_car = Car(
            userId=client_user.id,
            brand="Audi",
            model="A6",
            number="А123БВ777",
            isPrimary=True,
        )
        db_session.add(client_car)
        await db_session.commit()

        # Admin creates appointment for client using client's car
        response = await async_client.post(
            "/api/appointments/",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "id": "test-admin-appt-car",
                "clientName": "Target Client",
                "carModel": "",
                "carNumber": "",
                "carId": client_car.id,
                "dateTime": "2026-06-10T11:00:00",
                "washTypeId": "w1",
                "additionalServices": "[]",
                "ownerUsername": "target_client",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["carModel"] == "Audi A6"
        assert data["carNumber"] == "А123БВ777"
        assert data["ownerUsername"] == "target_client"
