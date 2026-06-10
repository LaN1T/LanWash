import pytest


class TestReviews:
    """Тесты CRUD отзывов."""

    async def _create_appointment(self, async_client, token, appt_id, date_time, status="scheduled", owner="client_test"):
        """Хелпер для создания записи."""
        resp = await async_client.post(
            "/api/appointments/",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "id": appt_id,
                "clientName": "Тест Клиент",
                "carModel": "Toyota Camry",
                "carNumber": "А123БВ77",
                "dateTime": date_time,
                "washTypeId": "w1",
                "additionalServices": "[]",
                "status": status,
                "notes": "Тестовые заметки",
                "isFavorite": False,
                "ownerUsername": owner,
                "promoPrice": 0,
                "paidPrice": 1000,
                "isModifiedByAdmin": False,
                "isModifiedByWasher": False,
                "isSeenByClient": True,
                "originalPrice": 1000,
                "assignedWasher": "[]",
                "promoId": None,
                "box_index": 0,
            },
        )
        return resp

    async def _get_client_user(self, async_client, token):
        """Получает текущего пользователя по токену."""
        resp = await async_client.get(
            "/api/auth/washers",
            headers={"Authorization": f"Bearer {token}"},
        )
        # Используем /auth/me если есть, иначе получаем через профиль
        # Но в данном проекте нет /auth/me, поэтому получаем из контекста login
        # client_token фикстура не возвращает user_id, так что залогинимся заново
        login_resp = await async_client.post("/api/auth/login", json={
            "username": "client_test",
            "password": "TestPass123!",
        })
        return login_resp.json()["user"]

    @pytest.mark.asyncio
    async def test_create_review_with_appointment(self, async_client, client_token):
        user = await self._get_client_user(async_client, client_token)
        appt_resp = await self._create_appointment(
            async_client, client_token, "appt_review_1", "2099-05-01T10:00:00", status="scheduled"
        )
        assert appt_resp.status_code == 200

        # Обновляем статус на completed (клиент может редактировать свою запись)
        update_resp = await async_client.put(
            "/api/appointments/appt_review_1",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "id": "appt_review_1",
                "clientName": "Тест Клиент",
                "carModel": "Toyota Camry",
                "carNumber": "А123БВ77",
                "dateTime": "2099-05-01T10:00:00",
                "washTypeId": "w1",
                "additionalServices": "[]",
                "status": "completed",
                "notes": "Тестовые заметки",
                "isFavorite": False,
                "ownerUsername": "client_test",
                "promoPrice": 0,
                "paidPrice": 1000,
                "isModifiedByAdmin": False,
                "isModifiedByWasher": False,
                "isSeenByClient": True,
                "originalPrice": 1000,
                "assignedWasher": "[]",
                "promoId": None,
                "box_index": 0,
            },
        )
        assert update_resp.status_code == 200

        resp = await async_client.post(
            "/api/reviews/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "userId": user["id"],
                "rating": 5,
                "comment": "Отличная мойка!",
                "appointmentId": "appt_review_1",
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["rating"] == 5
        assert data["comment"] == "Отличная мойка!"
        assert data["appointmentId"] == "appt_review_1"
        assert data["isPublished"] is False

    @pytest.mark.asyncio
    async def test_create_review_with_non_completed_appointment(self, async_client, client_token):
        user = await self._get_client_user(async_client, client_token)
        appt_resp = await self._create_appointment(
            async_client, client_token, "appt_review_2", "2099-05-02T10:00:00", status="scheduled"
        )
        assert appt_resp.status_code == 200

        resp = await async_client.post(
            "/api/reviews/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "userId": user["id"],
                "rating": 4,
                "comment": "Хорошо",
                "appointmentId": "appt_review_2",
            },
        )
        assert resp.status_code == 400
        assert "только на завершённую мойку" in resp.json()["detail"]

    @pytest.mark.asyncio
    async def test_create_review_with_other_user_appointment(self, async_client, client_token):
        from database import AsyncSessionLocal
        from db_models import User
        from services.auth_service import get_password_hash

        async with AsyncSessionLocal() as session:
            other_user = User(
                username="other_client",
                passwordHash=get_password_hash("TestPass123!"),
                role="client",
                displayName="Other Client",
                createdAt="2099-01-01T00:00:00",
            )
            session.add(other_user)
            await session.commit()
            await session.refresh(other_user)
            other_user_id = other_user.id

        login_resp = await async_client.post("/api/auth/login", json={
            "username": "other_client",
            "password": "TestPass123!",
        })
        assert login_resp.status_code == 200
        other_token = login_resp.json()["access_token"]

        appt_resp = await self._create_appointment(
            async_client, other_token, "appt_review_3", "2099-05-03T10:00:00", status="completed", owner="other_client"
        )
        assert appt_resp.status_code == 200

        user = await self._get_client_user(async_client, client_token)
        resp = await async_client.post(
            "/api/reviews/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "userId": user["id"],
                "rating": 5,
                "comment": "Отлично",
                "appointmentId": "appt_review_3",
            },
        )
        assert resp.status_code == 403
        assert "чужую запись" in resp.json()["detail"]

    @pytest.mark.asyncio
    async def test_create_review_without_appointment(self, async_client, client_token):
        user = await self._get_client_user(async_client, client_token)
        resp = await async_client.post(
            "/api/reviews/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "userId": user["id"],
                "rating": 3,
                "comment": "Нормально",
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["rating"] == 3
        assert data["comment"] == "Нормально"
        assert data["appointmentId"] is None

    @pytest.mark.asyncio
    async def test_list_my_reviews(self, async_client, client_token):
        user = await self._get_client_user(async_client, client_token)
        resp = await async_client.post(
            "/api/reviews/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "userId": user["id"],
                "rating": 5,
                "comment": "Супер",
            },
        )
        assert resp.status_code == 200

        my_resp = await async_client.get(
            "/api/reviews/my",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert my_resp.status_code == 200
        data = my_resp.json()
        assert isinstance(data, list)
        assert len(data) >= 1
        assert any(r["comment"] == "Супер" for r in data)

    @pytest.mark.asyncio
    async def test_list_reviews_published_filter(self, async_client, client_token):
        resp = await async_client.get("/api/reviews/?published=true")
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)
        for r in data:
            assert r["isPublished"] is True

    @pytest.mark.asyncio
    async def test_create_duplicate_review(self, async_client, client_token):
        user = await self._get_client_user(async_client, client_token)
        appt_resp = await self._create_appointment(
            async_client, client_token, "appt_review_dup", "2099-05-04T10:00:00", status="scheduled", owner="client_test"
        )
        assert appt_resp.status_code == 200

        # Обновляем статус на completed
        update_resp = await async_client.put(
            "/api/appointments/appt_review_dup",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "id": "appt_review_dup",
                "clientName": "Тест Клиент",
                "carModel": "Toyota Camry",
                "carNumber": "А123БВ77",
                "dateTime": "2099-05-04T10:00:00",
                "washTypeId": "w1",
                "additionalServices": "[]",
                "status": "completed",
                "notes": "Тестовые заметки",
                "isFavorite": False,
                "ownerUsername": "client_test",
                "promoPrice": 0,
                "paidPrice": 1000,
                "isModifiedByAdmin": False,
                "isModifiedByWasher": False,
                "isSeenByClient": True,
                "originalPrice": 1000,
                "assignedWasher": "[]",
                "promoId": None,
                "box_index": 0,
            },
        )
        assert update_resp.status_code == 200

        resp = await async_client.post(
            "/api/reviews/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "userId": user["id"],
                "rating": 5,
                "comment": "Отличная мойка!",
                "appointmentId": "appt_review_dup",
            },
        )
        assert resp.status_code == 200

        resp2 = await async_client.post(
            "/api/reviews/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "userId": user["id"],
                "rating": 4,
                "comment": "Повторный отзыв",
                "appointmentId": "appt_review_dup",
            },
        )
        assert resp2.status_code == 409
        assert "уже существует" in resp2.json()["detail"]

    @pytest.mark.asyncio
    async def test_create_review_user_name_from_auth(self, async_client, client_token):
        user = await self._get_client_user(async_client, client_token)
        resp = await async_client.post(
            "/api/reviews/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "userId": user["id"],
                "rating": 5,
                "comment": "Тест подмены имени",
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["userName"] == user["displayName"]
        assert data["userName"] != "Spoofed Name"

    @pytest.mark.asyncio
    async def test_has_review_endpoint(self, async_client, client_token):
        user = await self._get_client_user(async_client, client_token)
        appt_resp = await self._create_appointment(
            async_client, client_token, "appt_review_has", "2099-05-05T10:00:00", status="scheduled", owner="client_test"
        )
        assert appt_resp.status_code == 200

        # Обновляем статус на completed
        update_resp = await async_client.put(
            "/api/appointments/appt_review_has",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "id": "appt_review_has",
                "clientName": "Тест Клиент",
                "carModel": "Toyota Camry",
                "carNumber": "А123БВ77",
                "dateTime": "2099-05-05T10:00:00",
                "washTypeId": "w1",
                "additionalServices": "[]",
                "status": "completed",
                "notes": "Тестовые заметки",
                "isFavorite": False,
                "ownerUsername": "client_test",
                "promoPrice": 0,
                "paidPrice": 1000,
                "isModifiedByAdmin": False,
                "isModifiedByWasher": False,
                "isSeenByClient": True,
                "originalPrice": 1000,
                "assignedWasher": "[]",
                "promoId": None,
                "box_index": 0,
            },
        )
        assert update_resp.status_code == 200

        # До создания отзыва — false
        resp_before = await async_client.get(
            "/api/reviews/has-review?appointment_id=appt_review_has",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert resp_before.status_code == 200
        assert resp_before.json()["hasReview"] is False

        # Создаём отзыв
        resp_create = await async_client.post(
            "/api/reviews/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "userId": user["id"],
                "rating": 5,
                "comment": "Тест has-review",
                "appointmentId": "appt_review_has",
            },
        )
        assert resp_create.status_code == 200

        # После создания отзыва — true
        resp_after = await async_client.get(
            "/api/reviews/has-review?appointment_id=appt_review_has",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert resp_after.status_code == 200
        assert resp_after.json()["hasReview"] is True
