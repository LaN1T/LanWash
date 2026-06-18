import os
import sys

# Ensure backend is in PYTHONPATH
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest

from app.routers.auth import router as auth_router


class TestRateLimitGlobal:
    @pytest.mark.asyncio
    async def test_global_rate_limit_not_applied_in_tests(self, async_client):
        """Rate limiting is disabled in tests via conftest.py —
        requests should succeed.
        """
        response = await async_client.get("/health")
        assert response.status_code == 200

    def test_auth_login_rate_limit_decorator_exists(self):
        """Verify the login endpoint has a rate limit decorator applied."""
        login_route = next(
            r
            for r in auth_router.routes
            if r.path == "/api/auth/login" and r.methods == {"POST"}
        )
        # limiter.limit uses functools.wraps, so __wrapped__ points to original function
        assert hasattr(login_route.endpoint, "__wrapped__")

    def test_auth_register_rate_limit_decorator_exists(self):
        """Verify the register endpoint has a rate limit decorator applied."""
        register_route = next(
            r
            for r in auth_router.routes
            if r.path == "/api/auth/register" and r.methods == {"POST"}
        )
        assert hasattr(register_route.endpoint, "__wrapped__")
