import pytest
import pytest_asyncio
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from core.security_headers import SecurityHeadersMiddleware


@pytest.fixture
def app():
    app = FastAPI()
    app.add_middleware(SecurityHeadersMiddleware)

    @app.get("/")
    async def root():
        return {"message": "hello"}

    return app


@pytest_asyncio.fixture
async def client(app):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


class TestSecurityHeaders:
    @pytest.mark.asyncio
    async def test_csp_header(self, client):
        response = await client.get("/")
        assert response.status_code == 200
        csp = response.headers.get("Content-Security-Policy")
        assert csp is not None
        assert "default-src 'self'" in csp

    @pytest.mark.asyncio
    async def test_hsts_header(self, client):
        response = await client.get("/")
        assert response.status_code == 200
        hsts = response.headers.get("Strict-Transport-Security")
        assert hsts is not None
        assert "max-age=31536000" in hsts

    @pytest.mark.asyncio
    async def test_permissions_policy(self, client):
        response = await client.get("/")
        assert response.status_code == 200
        pp = response.headers.get("Permissions-Policy")
        assert pp is not None
        assert "camera=()" in pp
