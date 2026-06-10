from datetime import datetime, timedelta

import pytest

from db_models import Appointment, Review, User


class TestAdminDashboard:
    @pytest.mark.asyncio
    async def test_dashboard_admin_access(self, async_client, admin_token):
        """Admin can access dashboard."""
        today = datetime.now().strftime("%Y-%m-%d")
        week_ago = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")
        response = await async_client.get(
            f"/api/admin/dashboard?from_date={week_ago}&to_date={today}",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "totalRevenue" in data
        assert "totalAppointments" in data
        assert "dailyBreakdown" in data
        assert len(data["dailyBreakdown"]) == 8  # 7 days + today

    @pytest.mark.asyncio
    async def test_dashboard_forbidden_client(self, async_client, client_token):
        """Client cannot access dashboard."""
        today = datetime.now().strftime("%Y-%m-%d")
        week_ago = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")
        response = await async_client.get(
            f"/api/admin/dashboard?from_date={week_ago}&to_date={today}",
            headers={"Authorization": f"Bearer {client_token}"}
        )
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_dashboard_invalid_date_format(self, async_client, admin_token):
        """Invalid date format returns 400."""
        response = await async_client.get(
            "/api/admin/dashboard?from_date=invalid&to_date=2024-01-01",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_dashboard_from_after_to(self, async_client, admin_token):
        """from_date after to_date returns 400."""
        response = await async_client.get(
            "/api/admin/dashboard?from_date=2024-12-31&to_date=2024-01-01",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_dashboard_with_data(self, async_client, db_session, admin_token):
        """Dashboard returns correct aggregated data."""
        today = datetime.now()
        today_str = today.strftime("%Y-%m-%d")

        # Create test user for review
        test_client = User(
            username="dash_client_user",
            passwordHash="fakehash",
            role="client",
            displayName="Dash Client User",
            createdAt=today.isoformat(),
        )
        db_session.add(test_client)
        await db_session.commit()
        await db_session.refresh(test_client)

        # Create a completed appointment
        appt = Appointment(
            id="dash_appt_1",
            clientName="Dash Client",
            carModel="Test",
            carNumber="А123БВ777",
            dateTime=today.isoformat(),
            washTypeId="w2",
            additionalServices="[]",
            status="completed",
            ownerUsername="dash_client_user",
            box_index=1,
            paidPrice=1500,
            assignedWasher='["washer_test"]',
        )
        db_session.add(appt)

        # Create a review
        review = Review(
            userId=test_client.id,
            userName="Dash Client User",
            rating=5,
            comment="Great",
            isPublished=True,
            createdAt=today.isoformat(),
        )
        db_session.add(review)
        await db_session.commit()

        response = await async_client.get(
            f"/api/admin/dashboard?from_date={today_str}&to_date={today_str}",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["totalRevenue"] == 1500
        assert data["completedAppointments"] == 1
        assert data["averageRating"] == 5.0
        assert data["averageCheck"] == 1500.0
        assert len(data["dailyBreakdown"]) == 1
        assert data["dailyBreakdown"][0]["revenue"] == 1500

    @pytest.mark.asyncio
    async def test_dashboard_top_washers_and_clients(self, async_client, db_session, admin_token):
        """Dashboard returns top washers and clients."""
        today = datetime.now()
        today_str = today.strftime("%Y-%m-%d")

        appt = Appointment(
            id="dash_appt_2",
            clientName="Dash Client",
            carModel="Test",
            carNumber="А123БВ777",
            dateTime=today.isoformat(),
            washTypeId="w2",
            additionalServices="[]",
            status="completed",
            ownerUsername="client_test",
            box_index=1,
            paidPrice=2000,
            assignedWasher='["washer_test"]',
        )
        db_session.add(appt)
        await db_session.commit()

        response = await async_client.get(
            f"/api/admin/dashboard?from_date={today_str}&to_date={today_str}",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data["topWashers"]) >= 1
        assert len(data["topClients"]) >= 1
        assert data["topWashers"][0]["revenue"] == 2000
        assert data["topClients"][0]["visits"] == 1
