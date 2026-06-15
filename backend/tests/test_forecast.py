from datetime import datetime, timedelta

import pytest
from db_models import Appointment
from models import ForecastResponse, ForecastSlot
from services.forecast_service import generate_forecast


class TestForecastModels:
    @pytest.mark.asyncio
    async def test_forecast_models_exist(self):
        """Pydantic forecast models can be instantiated."""
        slot = ForecastSlot(
            date="2024-06-03",
            hour=10,
            predicted_load=1.0,
            capacity=2,
            utilization_pct=50.0,
        )
        response = ForecastResponse(
            items=[slot],
            generated_at=datetime.now().isoformat(),
        )
        assert response.items[0].date == "2024-06-03"
        assert response.items[0].hour == 10
        assert response.items[0].predicted_load == 1.0
        assert response.items[0].capacity == 2


class TestForecastService:
    @pytest.mark.asyncio
    async def test_generate_forecast_basic(self, db_session):
        """Historical appointments produce expected average load."""
        # 2024-06-03 is a Monday
        reference_date = datetime(2024, 6, 3, 0, 0, 0)

        # Create 4 Monday appointments at 10:00 over the previous 4 weeks
        for weeks_ago in (4, 3, 2, 1):
            appt_date = reference_date - timedelta(weeks=weeks_ago)
            appt = Appointment(
                id=f"forecast_appt_{weeks_ago}",
                clientName="Forecast Client",
                carModel="Test",
                carNumber="А123БВ777",
                dateTime=appt_date.replace(hour=10, minute=0, second=0).isoformat(),
                washTypeId="w2",
                additionalServices="[]",
                status="completed",
                ownerUsername="client_test",
                box_index=0,
                paidPrice=1000,
            )
            db_session.add(appt)
        await db_session.commit()

        forecast = await generate_forecast(
            db_session, reference_date=reference_date, days=1
        )

        monday_10 = next(
            s
            for s in forecast.items
            if s.date == reference_date.strftime("%Y-%m-%d") and s.hour == 10
        )
        assert monday_10.predicted_load == 1.0
        assert monday_10.capacity == 2
        assert monday_10.utilization_pct == 50.0


class TestForecastEndpoint:
    @pytest.mark.asyncio
    async def test_forecast_endpoint_admin_access(self, async_client, admin_token):
        """Admin can access the forecast endpoint."""
        response = await async_client.get(
            "/api/admin/forecast?days=7",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert "generated_at" in data
        assert len(data["items"]) == 91  # 7 days * 13 hours (08..20)

    @pytest.mark.asyncio
    async def test_forecast_endpoint_non_admin_forbidden(
        self, async_client, client_token
    ):
        """Non-admin users cannot access the forecast endpoint."""
        response = await async_client.get(
            "/api/admin/forecast?days=7",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403
