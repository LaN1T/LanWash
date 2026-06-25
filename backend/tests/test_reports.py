import pytest


class TestReports:
    """Тесты отчётов (admin only)."""

    async def _create_appointment(
        self,
        async_client,
        token,
        appt_id,
        date_time,
        paid_price=1000,
        *,
        status="completed",
        assigned_washer=None,
        promo_id=None,
        wash_type_id="w1",
        cancel_reason="",
    ):
        """Хелпер для создания записи с нужным статусом и параметрами."""
        payload = {
            "id": appt_id,
            "clientName": "Тест Клиент",
            "carModel": "Toyota Camry",
            "carNumber": "А123БВ77",
            "dateTime": date_time,
            "washTypeId": wash_type_id,
            "additionalServices": "[]",
            "status": status,
            "notes": "",
            "isFavorite": False,
            "ownerUsername": "client_test",
            "promoPrice": 0,
            "paidPrice": paid_price,
            "isModifiedByAdmin": False,
            "isModifiedByWasher": False,
            "isSeenByClient": True,
            "originalPrice": paid_price,
            "assignedWasher": "[]",
            "promoId": promo_id,
            "box_index": 0,
            "cancel_reason": cancel_reason,
        }
        if assigned_washer:
            payload["assignedWasher"] = f'["{assigned_washer}"]'
        resp = await async_client.post(
            "/api/appointments/",
            headers={"Authorization": f"Bearer {token}"},
            json=payload,
        )
        return resp

    async def _create_completed_appointment(
        self, async_client, token, appt_id, date_time, paid_price=1000
    ):
        """Хелпер для создания завершённой записи."""
        return await self._create_appointment(
            async_client,
            token,
            appt_id,
            date_time,
            paid_price,
        )

    @pytest.mark.asyncio
    async def test_monthly_report(self, async_client, admin_token, client_token):
        # Создаём завершённую запись в январе 2099
        await self._create_completed_appointment(
            async_client, admin_token, "rep_appt_1", "2099-01-15T10:00:00", 1500
        )

        response = await async_client.get(
            "/api/reports/monthly-check-vs-price/?date=2099-01",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["month"] == "2099-01"
        assert len(data["items"]) >= 1
        # Проверяем структуру
        row = data["items"][0]
        assert "car_model" in row
        assert "avg_check" in row
        assert "visit_count" in row
        assert "avgCarPrice" not in row

    @pytest.mark.asyncio
    async def test_popular_services_report(
        self, async_client, admin_token, client_token
    ):
        await self._create_completed_appointment(
            async_client, admin_token, "rep_appt_2", "2099-02-10T14:00:00", 2000
        )

        response = await async_client.get(
            "/api/reports/popular-additional-services/?date=2099-02",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["month"] == "2099-02"
        assert isinstance(data["items"], list)

    @pytest.mark.asyncio
    async def test_consumables_usage_report(
        self, async_client, admin_token, client_token
    ):
        # Создаём запись с типом мойки w1 (express) — расходуется шампунь
        await self._create_completed_appointment(
            async_client, admin_token, "rep_appt_3", "2099-03-05T09:00:00", 500
        )

        response = await async_client.get(
            "/api/reports/consumables-usage/?date=2099-03",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["month"] == "2099-03"
        # Должен быть расход шампуня для w1
        names = [item["consumable_name"] for item in data["items"]]
        assert "Автошампунь" in names

    @pytest.mark.asyncio
    async def test_monthly_report_day_mode(self, async_client, admin_token):
        await self._create_completed_appointment(
            async_client, admin_token, "rep_appt_1_day", "2099-01-15T10:00:00", 1500
        )

        response = await async_client.get(
            "/api/reports/monthly-check-vs-price/?date=2099-01-15",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["month"] == "2099-01-15"
        assert any(item["car_model"] == "Toyota Camry" for item in data["items"])

    @pytest.mark.asyncio
    async def test_popular_services_report_day_mode(
        self, async_client, admin_token
    ):
        await self._create_completed_appointment(
            async_client, admin_token, "rep_appt_2_day", "2099-02-10T14:00:00", 2000
        )

        response = await async_client.get(
            "/api/reports/popular-additional-services/?date=2099-02-10",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["month"] == "2099-02-10"
        assert isinstance(data["items"], list)

    @pytest.mark.asyncio
    async def test_consumables_usage_report_day_mode(
        self, async_client, admin_token
    ):
        await self._create_completed_appointment(
            async_client, admin_token, "rep_appt_3_day", "2099-03-05T09:00:00", 500
        )

        response = await async_client.get(
            "/api/reports/consumables-usage/?date=2099-03-05",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["month"] == "2099-03-05"
        names = [item["consumable_name"] for item in data["items"]]
        assert "Автошампунь" in names

    @pytest.mark.asyncio
    async def test_reports_forbidden(self, async_client, client_token):
        response = await async_client.get(
            "/api/reports/monthly-check-vs-price/",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_financial_report_json(self, async_client, admin_token):
        await self._create_completed_appointment(
            async_client,
            admin_token,
            "rep_appt_fin",
            "2026-06-15T10:00:00",
            2500,
        )

        resp = await async_client.get(
            "/api/reports/financial/?start_date=2026-06-01&end_date=2026-06-30&group_by=day",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "summary" in data
        assert "items" in data
        assert isinstance(data["items"], list)
        assert data["summary"]["revenue"] >= 2500

    @pytest.mark.asyncio
    async def test_financial_report_excel(self, async_client, admin_token):
        resp = await async_client.get(
            "/api/reports/financial/?start_date=2026-06-01&end_date=2026-06-30&format=xlsx",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        assert (
            resp.headers["content-type"]
            == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
        assert len(resp.content) > 0

    @pytest.mark.asyncio
    async def test_washer_payroll_report_json(
        self, async_client, admin_token, washer_token
    ):
        await self._create_appointment(
            async_client,
            admin_token,
            "rep_appt_payroll",
            "2026-06-15T11:00:00",
            1800,
            assigned_washer="washer_test",
        )

        resp = await async_client.get(
            "/api/reports/washer-payroll/?start_date=2026-06-01&end_date=2026-06-30",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "items" in data
        assert any(
            item["washer_username"] == "washer_test" for item in data["items"]
        )

    @pytest.mark.asyncio
    async def test_washer_payroll_report_excel(self, async_client, admin_token):
        resp = await async_client.get(
            "/api/reports/washer-payroll/?start_date=2026-06-01&end_date=2026-06-30&format=xlsx",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        assert (
            resp.headers["content-type"]
            == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
        assert len(resp.content) > 0

    @pytest.mark.asyncio
    async def test_cancellations_report_json(self, async_client, admin_token):
        await self._create_appointment(
            async_client,
            admin_token,
            "rep_appt_cancel",
            "2026-06-16T12:00:00",
            1200,
            status="cancelled",
            cancel_reason="По просьбе клиента",
        )

        resp = await async_client.get(
            "/api/reports/cancellations/?start_date=2026-06-01&end_date=2026-06-30",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "summary" in data
        assert "items" in data
        assert any(
            item["appointment_id"] == "rep_appt_cancel"
            for item in data["items"]
        )

    @pytest.mark.asyncio
    async def test_cancellations_report_excel(self, async_client, admin_token):
        resp = await async_client.get(
            "/api/reports/cancellations/?start_date=2026-06-01&end_date=2026-06-30&format=xlsx",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        assert (
            resp.headers["content-type"]
            == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
        assert len(resp.content) > 0

    @pytest.mark.asyncio
    async def test_promo_effectiveness_report_json(self, async_client, admin_token):
        await self._create_appointment(
            async_client,
            admin_token,
            "rep_appt_promo",
            "2026-06-17T13:00:00",
            1600,
            wash_type_id="w3",
            promo_id="promo_1",
        )

        resp = await async_client.get(
            "/api/reports/promo-effectiveness/?start_date=2026-06-01&end_date=2026-06-30",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "items" in data
        assert any(item["promo_id"] == "promo_1" for item in data["items"])

    @pytest.mark.asyncio
    async def test_promo_effectiveness_report_excel(self, async_client, admin_token):
        resp = await async_client.get(
            "/api/reports/promo-effectiveness/?start_date=2026-06-01&end_date=2026-06-30&format=xlsx",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        assert (
            resp.headers["content-type"]
            == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
        assert len(resp.content) > 0

    @pytest.mark.asyncio
    async def test_daily_report(self, async_client, admin_token):
        resp = await async_client.get(
            "/api/reports/daily/?date=2026-06-15",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "report_date" in data
        assert "revenue" in data
        assert "top_services" in data

    @pytest.mark.asyncio
    async def test_shift_load_report(self, async_client, admin_token):
        resp = await async_client.get(
            "/api/reports/shift-load/?start_date=2026-06-01&end_date=2026-06-07",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "dailyHours" in data
        assert "washerStats" in data
