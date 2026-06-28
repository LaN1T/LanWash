from datetime import datetime, timedelta

import pytest
from sqlalchemy import select

from models import Subscription, SubscriptionPlan, User


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

    async def _assert_subscription_in_my(
        self, async_client, client_token, subscription_id
    ):
        """Проверяет, что купленный абонемент виден в списке клиента."""
        resp = await async_client.get(
            "/api/subscriptions/my",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert any(s["id"] == subscription_id for s in data)

    @pytest.mark.asyncio
    async def test_client_can_list_subscription_plans(self, async_client, client_token):
        resp = await async_client.get(
            "/api/subscriptions/plans",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)
        assert len(data) >= 1
        required_fields = {"id", "code", "name", "type"}
        for plan in data:
            assert required_fields.issubset(plan.keys())

    @pytest.mark.asyncio
    async def test_client_buys_ready_subscription(
        self, async_client, client_token, db_session
    ):
        plan_res = await db_session.execute(
            select(SubscriptionPlan).where(SubscriptionPlan.code == "chistulya")
        )
        plan = plan_res.scalar_one()

        resp = await async_client.post(
            "/api/subscriptions/buy",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "kind": "ready",
                "ready": {"planId": plan.id, "washTypeId": "w3"},
            },
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["washTypeId"] == "w3"
        assert data["totalWashes"] == 5
        # chistulya: 5 моек со скидкой 10% на тип мойки w3 (basePrice=1500):
        # 1500 * 5 = 7500; 7500 * 0.90 = 6750
        assert data["price"] == 6750
        assert data["originalPrice"] == 7500
        assert data["paymentStatus"] == "demo_purchased"

        await self._assert_subscription_in_my(async_client, client_token, data["id"])

    @pytest.mark.asyncio
    async def test_client_buys_personal_subscription(self, async_client, client_token):
        resp = await async_client.post(
            "/api/subscriptions/buy",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "kind": "personal",
                "personal": {
                    "washTypeId": "w2",
                    "selectedExtras": ["s4"],
                    "washCount": 10,
                },
            },
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["washTypeId"] == "w2"
        assert data["totalWashes"] == 10
        # personal: w2 basePrice=800 + доп. услуга s4=600 = 1400 за мойку;
        # 10 моек дают скидку 10%: 1400 * 10 * 0.90 = 12600
        assert data["price"] == 12600
        assert data["originalPrice"] == 14000

        await self._assert_subscription_in_my(async_client, client_token, data["id"])

    @pytest.mark.asyncio
    async def test_client_buys_unlimited_subscription(
        self, async_client, client_token, db_session
    ):
        plan_res = await db_session.execute(
            select(SubscriptionPlan).where(SubscriptionPlan.code == "bezlimitka")
        )
        plan = plan_res.scalar_one()

        resp = await async_client.post(
            "/api/subscriptions/buy",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "kind": "ready",
                "ready": {"planId": plan.id, "washTypeId": "w1"},
            },
        )
        assert resp.status_code == 201
        data = resp.json()
        # bezlimitka для w1 стоит 8000, действует 30 дней
        assert data["price"] == 8000
        assert data["type"] == "monthly"
        assert data["validUntil"] is not None
        valid_until = datetime.fromisoformat(data["validUntil"]).date()
        assert valid_until > datetime.now().date() + timedelta(days=25)

        await self._assert_subscription_in_my(async_client, client_token, data["id"])

    @pytest.mark.asyncio
    async def test_non_admin_cannot_create_plan(self, async_client, client_token):
        resp = await async_client.post(
            "/api/subscriptions/admin/plans",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "code": "client-plan",
                "name": "Client Plan",
                "type": "package",
                "washCount": 3,
                "discountPercent": 5,
                "sortOrder": 99,
            },
        )
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_buy_subscription_invalid_plan_returns_404(
        self, async_client, client_token
    ):
        resp = await async_client.post(
            "/api/subscriptions/buy",
            headers={"Authorization": f"Bearer {client_token}"},
            json={
                "kind": "ready",
                "ready": {"planId": 999999, "washTypeId": "w1"},
            },
        )
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_admin_crud_subscription_plan(self, async_client, admin_token):
        create_resp = await async_client.post(
            "/api/subscriptions/admin/plans",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "code": "test-plan",
                "name": "Test Plan",
                "type": "package",
                "washCount": 3,
                "discountPercent": 5,
                "sortOrder": 99,
            },
        )
        assert create_resp.status_code == 201
        plan_id = create_resp.json()["id"]

        update_resp = await async_client.put(
            f"/api/subscriptions/admin/plans/{plan_id}",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"name": "Updated Plan"},
        )
        assert update_resp.status_code == 200
        assert update_resp.json()["name"] == "Updated Plan"

        delete_resp = await async_client.delete(
            f"/api/subscriptions/admin/plans/{plan_id}",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert delete_resp.status_code == 204

        list_resp = await async_client.get(
            "/api/subscriptions/admin/plans",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert list_resp.status_code == 200
        plans = list_resp.json()
        deleted_plan = next((p for p in plans if p["id"] == plan_id), None)
        assert deleted_plan is not None
        assert deleted_plan["isActive"] is False
