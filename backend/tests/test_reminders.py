from datetime import datetime, timedelta

import pytest
import pytest_asyncio

from db_models import Appointment, FcmToken, User
from services.reminder_service import check_and_send_reminders


@pytest_asyncio.fixture
async def setup_client_with_history(db_session):
    """Create a client with 3 completed appointments spaced 7 days apart."""
    # Create client
    client = User(
        username="history_client",
        passwordHash="fakehash",
        role="client",
        displayName="History Client",
        phone="",
        carModel="",
        carNumber="",
        createdAt=datetime.now().isoformat()
    )
    db_session.add(client)
    await db_session.commit()
    await db_session.refresh(client)

    # Create 3 appointments, 7 days apart, all completed
    base_date = datetime.now() - timedelta(days=30)
    for i in range(3):
        appt = Appointment(
            id=f"hist_appt_{i}",
            clientName=client.displayName,
            carModel="Test Car",
            carNumber="А123БВ777",
            dateTime=(base_date + timedelta(days=i * 7)).isoformat(),
            washTypeId="w2",
            additionalServices="[]",
            status="completed",
            ownerUsername=client.username,
            box_index=1
        )
        db_session.add(appt)
    await db_session.commit()

    return client


class TestReminders:
    @pytest.mark.asyncio
    async def test_reminder_sent_when_overdue(self, async_client, db_session, setup_client_with_history):
        """When last wash was 30 days ago and avg interval is 7 days, reminder should be sent."""
        user = setup_client_with_history

        # Add FCM token
        token = FcmToken(
            username=user.username,
            token="test_token_reminder_1",
            platform="android",
            updatedAt=datetime.now().isoformat()
        )
        db_session.add(token)
        await db_session.commit()

        result = await check_and_send_reminders(db_session)
        assert result["sent"] >= 1
        assert result["errors"] == 0

    @pytest.mark.asyncio
    async def test_reminder_skipped_when_recent(self, async_client, db_session):
        """When last wash was yesterday, no reminder should be sent."""
        # Create client with very recent completed appointment
        client_user = User(
            username="recent_client",
            passwordHash="fakehash",
            role="client",
            displayName="Recent Client",
            phone="",
            carModel="",
            carNumber="",
            createdAt=datetime.now().isoformat()
        )
        db_session.add(client_user)
        await db_session.commit()
        await db_session.refresh(client_user)

        # Two appointments 7 days apart, last one yesterday
        yesterday = datetime.now() - timedelta(days=1)
        week_ago = datetime.now() - timedelta(days=8)
        for dt, idx in [(week_ago, 0), (yesterday, 1)]:
            appt = Appointment(
                id=f"recent_appt_{idx}",
                clientName=client_user.displayName,
                carModel="Test Car",
                carNumber="А123БВ777",
                dateTime=dt.isoformat(),
                washTypeId="w2",
                additionalServices="[]",
                status="completed",
                ownerUsername=client_user.username,
                box_index=1
            )
            db_session.add(appt)
        await db_session.commit()

        result = await check_and_send_reminders(db_session)
        assert result["sent"] == 0
        assert result["skipped"] >= 1

    @pytest.mark.asyncio
    async def test_reminder_skipped_with_few_appointments(self, async_client, db_session):
        """Clients with only 1 completed appointment should be skipped."""
        client_user = User(
            username="single_client",
            passwordHash="fakehash",
            role="client",
            displayName="Single Client",
            phone="",
            carModel="",
            carNumber="",
            createdAt=datetime.now().isoformat()
        )
        db_session.add(client_user)
        await db_session.commit()
        await db_session.refresh(client_user)

        appt = Appointment(
            id="single_appt",
            clientName=client_user.displayName,
            carModel="Test Car",
            carNumber="А123БВ777",
            dateTime=(datetime.now() - timedelta(days=30)).isoformat(),
            washTypeId="w2",
            additionalServices="[]",
            status="completed",
            ownerUsername=client_user.username,
            box_index=1
        )
        db_session.add(appt)
        await db_session.commit()

        result = await check_and_send_reminders(db_session)
        assert result["sent"] == 0
        assert result["skipped"] >= 1

    @pytest.mark.asyncio
    async def test_trigger_reminders_endpoint_admin(self, async_client, admin_token):
        """Admin can trigger reminders via endpoint."""
        response = await async_client.post(
            "/api/admin/trigger-reminders",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "sent" in data
        assert "skipped" in data
        assert "errors" in data

    @pytest.mark.asyncio
    async def test_trigger_reminders_endpoint_forbidden_client(self, async_client, client_token):
        """Client cannot trigger reminders."""
        response = await async_client.post(
            "/api/admin/trigger-reminders",
            headers={"Authorization": f"Bearer {client_token}"}
        )
        assert response.status_code == 403
