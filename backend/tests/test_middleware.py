import pytest


class TestAppCheckMiddleware:
    @pytest.mark.asyncio
    async def test_app_check_calls_verify_for_non_excluded_path(
        self, async_client, monkeypatch
    ):
        from app import middleware
        from core import app_check

        called = False

        async def _capture_call(request):
            nonlocal called
            called = True

        monkeypatch.setattr(app_check, "verify_app_check_token", _capture_call)
        monkeypatch.setattr(middleware, "verify_app_check_token", _capture_call)

        await async_client.get("/api/auth/washers")
        assert called is True

    @pytest.mark.asyncio
    async def test_webhook_path_excluded_from_app_check(
        self, async_client, monkeypatch
    ):
        from app import middleware
        from core import app_check

        called = False

        async def _capture_call(request):
            nonlocal called
            called = True

        monkeypatch.setattr(app_check, "verify_app_check_token", _capture_call)
        monkeypatch.setattr(middleware, "verify_app_check_token", _capture_call)

        response = await async_client.post("/webhook/telegram")
        assert called is False
        assert response.status_code not in (401, 403)

    def test_is_app_check_excluded_logic(self):
        from app.middleware import _is_app_check_excluded

        assert _is_app_check_excluded("/webhook") is True
        assert _is_app_check_excluded("/webhook/telegram") is True
        assert _is_app_check_excluded("/uploads/image.png") is True
        assert _is_app_check_excluded("/landing/page") is True
        assert _is_app_check_excluded("/static/app.js") is True
        assert _is_app_check_excluded("/api/auth/washers") is False
        assert _is_app_check_excluded("/health") is True
