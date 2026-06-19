from datetime import datetime

import pytest


class TestReferralRegistration:
    @pytest.mark.asyncio
    async def test_register_with_referral_code(self, async_client, db_session):
        # Create referrer user directly in DB with a known referral code
        from models import User
        from services.auth_service import get_password_hash

        referrer = User(
            username="referrer_user",
            passwordHash=get_password_hash("TestPass123!"),
            role="client",
            displayName="Referrer",
            createdAt=datetime.now(),
            referralCode="LANWASH1",
        )
        db_session.add(referrer)
        await db_session.commit()

        # Register new user with referral code
        response = await async_client.post(
            "/api/auth/register",
            json={
                "username": "referred_user",
                "password": "TestPass123!",
                "displayName": "Referred",
                "referralCode": "LANWASH1",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["user"]["referralCode"] is not None

        # Verify referral row was created
        from sqlalchemy import select

        from models import Referral

        result = await db_session.execute(
            select(Referral).where(Referral.referrerId == referrer.id)
        )
        referral = result.scalar_one_or_none()
        assert referral is not None
        assert referral.referredId == data["user"]["id"]
        assert referral.rewardClaimed is False

    @pytest.mark.asyncio
    async def test_register_with_invalid_referral_code(self, async_client):
        response = await async_client.post(
            "/api/auth/register",
            json={
                "username": "bad_ref_user",
                "password": "TestPass123!",
                "displayName": "Bad Ref",
                "referralCode": "INVALID1",
            },
        )
        assert response.status_code == 400
        assert "Неверный реферальный код" in response.json()["detail"]

    @pytest.mark.asyncio
    async def test_cannot_self_refer(self, async_client, db_session):
        # Create user with referral code
        from models import User
        from services.auth_service import get_password_hash

        referrer = User(
            username="self_ref_user",
            passwordHash=get_password_hash("TestPass123!"),
            role="client",
            displayName="Self Ref",
            createdAt=datetime.now(),
            referralCode="SELFREF1",
        )
        db_session.add(referrer)
        await db_session.commit()

        # Try to register with the same username and the same user's referral code
        response = await async_client.post(
            "/api/auth/register",
            json={
                "username": "self_ref_user",
                "password": "TestPass123!",
                "displayName": "Self Ref",
                "referralCode": "SELFREF1",
            },
        )
        assert response.status_code == 400
        assert "Нельзя использовать свой реферальный код" in response.json()["detail"]


class TestReferralStats:
    @pytest.mark.asyncio
    async def test_referral_stats_auto_generates_code(self, async_client, db_session):
        # Register a user without a referral code
        reg = await async_client.post(
            "/api/auth/register",
            json={
                "username": "auto_code_user",
                "password": "TestPass123!",
                "displayName": "Auto Code",
            },
        )
        assert reg.status_code == 200
        token = reg.json()["access_token"]

        # Call /referrals/my — should auto-generate code
        response = await async_client.get(
            "/api/referrals/my",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["referralCode"] is not None
        assert len(data["referralCode"]) == 8
        assert data["totalReferrals"] == 0
        assert data["claimedRewards"] == 0
        assert data["pendingRewards"] == 0

    @pytest.mark.asyncio
    async def test_referral_list(self, async_client, db_session):
        from models import Referral, User
        from services.auth_service import get_password_hash

        # Create referrer
        referrer = User(
            username="list_referrer",
            passwordHash=get_password_hash("TestPass123!"),
            role="client",
            displayName="List Referrer",
            createdAt=datetime.now(),
            referralCode="LISTREF1",
        )
        db_session.add(referrer)
        await db_session.commit()

        # Create referred user
        referred = User(
            username="list_referred",
            passwordHash=get_password_hash("TestPass123!"),
            role="client",
            displayName="List Referred",
            createdAt=datetime.now(),
            referralCode="LISTREF2",
        )
        db_session.add(referred)
        await db_session.commit()

        # Create referral
        db_session.add(
            Referral(
                referrerId=referrer.id,
                referredId=referred.id,
                rewardClaimed=False,
                createdAt=datetime.now(),
            )
        )
        await db_session.commit()

        # Login as referrer
        login = await async_client.post(
            "/api/auth/login",
            json={
                "username": "list_referrer",
                "password": "TestPass123!",
            },
        )
        token = login.json()["access_token"]

        # Get list
        response = await async_client.get(
            "/api/referrals/list",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]["referredName"] == "List Referred"
        assert data[0]["rewardClaimed"] is False


class TestClaimReward:
    @pytest.mark.asyncio
    async def test_claim_reward(self, async_client, db_session):
        from models import Referral, User
        from services.auth_service import get_password_hash

        # Create referrer
        referrer = User(
            username="claim_referrer",
            passwordHash=get_password_hash("TestPass123!"),
            role="client",
            displayName="Claim Referrer",
            createdAt=datetime.now(),
            referralCode="CLAIMREF",
        )
        db_session.add(referrer)
        await db_session.commit()

        # Create referred users
        referred1 = User(
            username="claim_referred1",
            passwordHash=get_password_hash("TestPass123!"),
            role="client",
            displayName="Referred 1",
            createdAt=datetime.now(),
            referralCode="CLAIMR01",
        )
        referred2 = User(
            username="claim_referred2",
            passwordHash=get_password_hash("TestPass123!"),
            role="client",
            displayName="Referred 2",
            createdAt=datetime.now(),
            referralCode="CLAIMR02",
        )
        db_session.add_all([referred1, referred2])
        await db_session.commit()

        # Create unclaimed referrals
        db_session.add_all(
            [
                Referral(
                    referrerId=referrer.id,
                    referredId=referred1.id,
                    rewardClaimed=False,
                    createdAt=datetime.now(),
                ),
                Referral(
                    referrerId=referrer.id,
                    referredId=referred2.id,
                    rewardClaimed=False,
                    createdAt=datetime.now(),
                ),
            ]
        )
        await db_session.commit()

        # Login
        login = await async_client.post(
            "/api/auth/login",
            json={
                "username": "claim_referrer",
                "password": "TestPass123!",
            },
        )
        token = login.json()["access_token"]

        # Claim
        response = await async_client.post(
            "/api/referrals/claim",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        assert response.json()["claimed"] == 2

        # Verify claimed
        from sqlalchemy import select

        result = await db_session.execute(
            select(Referral).where(Referral.referrerId == referrer.id)
        )
        for r in result.scalars().all():
            assert r.rewardClaimed is True

        # Claim again — should return 0
        response2 = await async_client.post(
            "/api/referrals/claim",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response2.status_code == 200
        assert response2.json()["claimed"] == 0
