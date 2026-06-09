import uuid
from contextvars import ContextVar

from starlette.middleware.base import BaseHTTPMiddleware

_request_id: ContextVar[str] = ContextVar("request_id")


def get_request_id() -> str:
    """Return the current request ID from the context variable."""
    try:
        return _request_id.get()
    except LookupError:
        return ""


class RequestIdMiddleware(BaseHTTPMiddleware):
    """Reads or generates X-Request-ID and propagates it to response headers."""

    async def dispatch(self, request, call_next):
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        token = _request_id.set(request_id)
        try:
            response = await call_next(request)
            response.headers["X-Request-ID"] = request_id
            return response
        finally:
            _request_id.reset(token)
