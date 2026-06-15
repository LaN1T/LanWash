from datetime import datetime, timedelta

import pytest
from db_models import Subscription, User
from sqlalchemy import select


class TestSubscriptions:
    """Тесты абонементов и пакетов моек."""

    async def _create_subscription(
        self,
        async_client,
        admin_token,
        user_id,
        name,
        sub_type,
        wash_type_id,
        total_washes,
        valid_until=None,
    ):
        """Хелпер для создания абонемента админом."""
        body = {
            "userId": user_id,
            "name": name,
            "type": sub_type,
            "washTypeId": wash_type_id,
            "totalWashes": total_washes,
        }
        if valid_until:
            body["validUntil"] = valid_until
        resp = await async_client.post(
            "/api/subscriptions/",
            headers={"Authorization": f"Bearer {admin_token}"},
            json=body,
        )
        return resp

    async def _create_appointment(
        self,
        async_client,
        token,
        appt_id,
        date_time,
        wash_type_id="w1",
        owner="client_test",
    ):
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
                "washTypeId": wash_type_id,
                "additionalServices": "[]",
                "status": "scheduled",
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

    @pytest.mark.asyncio
    async def test_create_subscription_admin(
        self, async_client, admin_token, client_token, db_session
    ):
        # Get client_test user id
        res = await db_session.execute(
            select(User).where(User.username == "client_test")
        )
        user = res.scalar_one()

        resp = await self._create_subscription(
            async_client,
            admin_token,
            user_id=user.id,
            name="Пакет 5 комплексных",
            sub_type="package",
            wash_type_id="w1",
            total_washes=5,
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["name"] == "Пакет 5 комплексных"
        assert data["type"] == "package"
        assert data["totalWashes"] == 5
        assert data["usedWashes"] == 0
        assert data["validUntil"] is None

    @pytest.mark.asyncio
    async def test_create_subscription_forbidden_client(
        self, async_client, client_token
    ):
        resp = await async_client.post(
            "/api/subscriptions/",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "userId": 1,
                "name": "Пакет",
                "type": "package",
                "washTypeId": "w1",
                "totalWashes": 5,
            },
        )
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_get_my_subscriptions(
        self, async_client, admin_token, client_token, db_session
    ):
        res = await db_session.execute(
            select(User).where(User.username == "client_test")
        )
        user = res.scalar_one()

        await self._create_subscription(
            async_client,
            admin_token,
            user_id=user.id,
            name="Мой пакет",
            sub_type="package",
            wash_type_id="w1",
            total_washes=3,
        )

        resp = await async_client.get(
            "/api/subscriptions/my",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)
        assert len(data) >= 1
        assert any(s["name"] == "Мой пакет" for s in data)

    @pytest.mark.asyncio
    async def test_appointment_with_active_subscription(
        self, async_client, admin_token, client_token, db_session
    ):
        res = await db_session.execute(
            select(User).where(User.username == "client_test")
        )
        user = res.scalar_one()

        sub_resp = await self._create_subscription(
            async_client,
            admin_token,
            user_id=user.id,
            name="Пакет 5",
            sub_type="package",
            wash_type_id="w1",
            total_washes=5,
        )
        sub_id = sub_resp.json()["id"]

        appt_resp = await self._create_appointment(
            async_client,
            client_token,
            "appt_sub_1",
            "2099-05-01T10:00:00",
            wash_type_id="w1",
        )
        assert appt_resp.status_code == 200
        data = appt_resp.json()
        assert data["paidPrice"] == 0
        assert data["subscriptionId"] == sub_id

        # Verify usedWashes incremented
        sub_res = await db_session.execute(
            select(Subscription).where(Subscription.id == sub_id)
        )
        sub = sub_res.scalar_one()
        assert sub.usedWashes == 1

    @pytest.mark.asyncio
    async def test_appointment_with_exhausted_subscription(
        self, async_client, admin_token, client_token, db_session
    ):
        res = await db_session.execute(
            select(User).where(User.username == "client_test")
        )
        user = res.scalar_one()

        sub_resp = await self._create_subscription(
            async_client,
            admin_token,
            user_id=user.id,
            name="Пакет 1",
            sub_type="package",
            wash_type_id="w1",
            total_washes=1,
        )
        sub_id = sub_resp.json()["id"]

        # First appointment uses the subscription
        appt1 = await self._create_appointment(
            async_client,
            client_token,
            "appt_sub_2",
            "2099-05-02T10:00:00",
            wash_type_id="w1",
        )
        assert appt1.status_code == 200
        assert appt1.json()["subscriptionId"] == sub_id

        # Second appointment should NOT use subscription (exhausted)
        appt2 = await self._create_appointment(
            async_client,
            client_token,
            "appt_sub_3",
            "2099-05-03T10:00:00",
            wash_type_id="w1",
        )
        assert appt2.status_code == 200
        data = appt2.json()
        assert data["subscriptionId"] is None

    @pytest.mark.asyncio
    async def test_appointment_with_expired_monthly_subscription(
        self, async_client, admin_token, client_token, db_session
    ):
        res = await db_session.execute(
            select(User).where(User.username == "client_test")
        )
        user = res.scalar_one()

        yesterday = (datetime.now() - timedelta(days=1)).isoformat()[:10]
        await self._create_subscription(
            async_client,
            admin_token,
            user_id=user.id,
            name="Месячный",
            sub_type="monthly",
            wash_type_id="w1",
            total_washes=10,
            valid_until=yesterday,
        )

        appt_resp = await self._create_appointment(
            async_client,
            client_token,
            "appt_sub_4",
            "2099-05-04T10:00:00",
            wash_type_id="w1",
        )
        assert appt_resp.status_code == 200
        data = appt_resp.json()
        assert data["subscriptionId"] is None

    @pytest.mark.asyncio
    async def test_subscription_stats(
        self, async_client, admin_token, client_token, db_session
    ):
        res = await db_session.execute(
            select(User).where(User.username == "client_test")
        )
        user = res.scalar_one()

        await self._create_subscription(
            async_client,
            admin_token,
            user_id=user.id,
            name="Статистика пакет",
            sub_type="package",
            wash_type_id="w1",
            total_washes=5,
        )

        stats_resp = await async_client.get(
            "/api/subscriptions/stats",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert stats_resp.status_code == 200
        data = stats_resp.json()
        assert "activeCount" in data
        assert "totalSaved" in data
        assert data["activeCount"] >= 1
