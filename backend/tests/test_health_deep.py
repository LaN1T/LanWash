import pytest


class TestHealth:
    @pytest.mark.asyncio
    async def test_health_basic(self, async_client):
        response = await async_client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "LanWash API"
        assert data["version"] == "1.0.0"
        assert "uptime_seconds" in data
        assert "environment" in data

    @pytest.mark.asyncio
    async def test_health_deep(self, async_client):
        response = await async_client.get("/health/deep")
        assert response.status_code == 200
        data = response.json()
        assert "status" in data
        assert "uptime_seconds" in data
        assert "checks" in data
        assert data["checks"]["database"]["status"] == "ok"
        assert "status" in data["checks"]["redis"]
