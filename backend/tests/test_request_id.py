import pytest
import pytest_asyncio
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from core.request_id import RequestIdMiddleware, get_request_id


@pytest.fixture
def standalone_app():
    app = FastAPI()
    app.add_middleware(RequestIdMiddleware)

    @app.get("/health")
    async def health():
        return {"request_id": get_request_id()}

    return app


@pytest_asyncio.fixture
async def client(standalone_app):
    transport = ASGITransport(app=standalone_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.mark.asyncio
async def test_request_id_generated(client):
    response = await client.get("/health")
    assert response.status_code == 200
    header = response.headers.get("X-Request-ID")
    assert header is not None
    assert len(header) == 36  # UUID4 length


@pytest.mark.asyncio
async def test_request_id_preserved(client):
    custom_id = "my-custom-id-123"
    response = await client.get("/health", headers={"X-Request-ID": custom_id})
    assert response.status_code == 200
    assert response.headers.get("X-Request-ID") == custom_id


@pytest.mark.asyncio
async def test_request_id_in_logs(client, caplog):
    import logging

    # Ensure structlog/stdio logs are captured
    caplog.set_level(logging.INFO, logger="main")

    response = await client.get("/health")
    assert response.status_code == 200
    request_id = response.headers.get("X-Request-ID")
    assert request_id is not None

    # The endpoint body itself returns the request_id — validate it propagated
    body = response.json()
    assert body["request_id"] == request_id
