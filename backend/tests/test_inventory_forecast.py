from datetime import datetime, timedelta

import pytest
from db_models import Consumable, ConsumableUsageLog
from models import ConsumableForecastItem, InventoryForecastResponse
from services.inventory_forecast_service import generate_inventory_forecast


class TestInventoryForecastModels:
    @pytest.mark.asyncio
    async def test_inventory_forecast_models_exist(self):
        """Pydantic inventory forecast models can be instantiated."""
        item = ConsumableForecastItem(
            consumable_id="c_forecast_test",
            name="Forecast Test",
            unit="ml",
            current_stock=300.0,
            min_stock=100.0,
            avg_daily_usage=10.0,
            planned_usage_7d=0.0,
            days_until_low=20.0,
            days_until_empty=30.0,
            recommended_order_amount=0.0,
            status="ok",
        )
        response = InventoryForecastResponse(
            items=[item],
            generated_at=datetime.now().isoformat(),
        )
        assert response.items[0].consumable_id == "c_forecast_test"
        assert response.items[0].avg_daily_usage == 10.0
        assert response.items[0].status == "ok"


class TestInventoryForecastService:
    @pytest.mark.asyncio
    async def test_inventory_forecast_calculation(self, db_session):
        """30 days of steady usage produces expected forecast values."""
        reference_date = datetime(2024, 6, 9, 12, 0, 0)

        consumable = Consumable(
            id="c_forecast_test",
            name="Forecast Test",
            unit="ml",
            currentStock=300.0,
            minStock=100.0,
        )
        db_session.add(consumable)

        for day in range(30):
            ts = (reference_date - timedelta(days=30 - day)).isoformat()
            db_session.add(
                ConsumableUsageLog(
                    appointmentId=f"appt_{day}",
                    consumableId="c_forecast_test",
                    quantityUsed=10.0,
                    timestamp=ts,
                )
            )
        await db_session.commit()

        forecast = await generate_inventory_forecast(
            db_session, reference_date=reference_date
        )
        item = next(i for i in forecast.items if i.consumable_id == "c_forecast_test")

        assert item.avg_daily_usage == 10.0
        assert item.days_until_low == 20.0
        assert item.days_until_empty == 30.0
        assert item.status == "ok"


class TestInventoryForecastTask:
    @pytest.mark.asyncio
    async def test_check_inventory_forecast_task(self, db_session):
        from datetime import datetime, timedelta

        from db_models import Consumable, ConsumableUsageLog
        from tasks import check_inventory_forecast

        # Create critical consumable: 30 stock, 100 minStock, high usage
        shampoo = Consumable(
            id="c_crit_task",
            name="Critical",
            unit="мл",
            currentStock=30.0,
            minStock=100.0,
        )
        db_session.add(shampoo)

        ref = datetime(2026, 6, 9, 12, 0, 0)
        for i in range(30):
            db_session.add(
                ConsumableUsageLog(
                    appointmentId=f"appt_{i}",
                    consumableId="c_crit_task",
                    quantityUsed=50.0,
                    timestamp=(ref - timedelta(days=i + 1)).isoformat(),
                )
            )
        await db_session.commit()

        result = await check_inventory_forecast(None, db=db_session)
        assert result["checked"] >= 1
        critical = [a for a in result["alerts"] if a["consumable_id"] == "c_crit_task"]
        assert len(critical) == 1
        assert critical[0]["status"] == "critical"


class TestInventoryForecastEndpoint:
    @pytest.mark.asyncio
    async def test_inventory_forecast_endpoint_access(self, async_client, admin_token):
        """Admin can access the inventory forecast endpoint."""
        response = await async_client.get(
            "/api/consumables/forecast",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert "generated_at" in data
        assert isinstance(data["items"], list)

    @pytest.mark.asyncio
    async def test_inventory_forecast_endpoint_client_forbidden(
        self, async_client, client_token
    ):
        """Client users cannot access the inventory forecast endpoint."""
        response = await async_client.get(
            "/api/consumables/forecast",
            headers={"Authorization": f"Bearer {client_token}"},
        )
        assert response.status_code == 403
