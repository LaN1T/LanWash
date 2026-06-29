import ipaddress

import jwt
from fastapi import Request
from slowapi import Limiter

from core.config import get_settings

settings = get_settings()
SECRET_KEY = settings.jwt_secret_key
ALGORITHM = "HS256"


def _is_trusted_proxy(host: str | None) -> bool:
    """Return True if the direct client IP is a private/local address.

    Only trust X-Forwarded-For / X-Real-IP headers when the immediate
    connection comes from a known internal/reverse-proxy address.
    """
    if not host:
        return True
    try:
        addr = ipaddress.ip_address(host)
    except ValueError:
        return False
    return addr.is_loopback or addr.is_private


def get_proxy_aware_remote_address(request: Request) -> str:
    direct_host = request.client.host if request.client else None
    if _is_trusted_proxy(direct_host):
        x_forwarded_for = request.headers.get("X-Forwarded-For")
        if x_forwarded_for:
            # Nginx appends the real client IP at the end of the chain.
            return x_forwarded_for.split(",")[-1].strip()
        x_real_ip = request.headers.get("X-Real-IP")
        if x_real_ip:
            return x_real_ip.strip()
    if direct_host:
        return direct_host
    return "127.0.0.1"


def _get_username_from_request(request: Request) -> str | None:
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None
    token = auth.split(" ", 1)[1]
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload.get("sub")
    except Exception:
        return None


def get_user_or_ip_key(request: Request) -> str:
    """Rate-limit key: authenticated users by username, others by IP."""
    username = _get_username_from_request(request)
    if username:
        return f"user:{username}"
    return get_proxy_aware_remote_address(request)


# Use Redis for rate limiting in production (multi-worker safe).
# In development/testing use in-memory storage so the backend runs without Redis.
_storage_uri = "memory://"
if settings.is_production:
    _redis_url = settings.redis_url
    if not _redis_url:
        raise RuntimeError(
            "REDIS_URL must be set in production for distributed rate limiting"
        )
    _storage_uri = _redis_url

if settings.disable_rate_limit:
    if settings.is_production:
        raise RuntimeError("DISABLE_RATE_LIMIT must not be set in production")

    class DummyLimiter:
        """No-op limiter for load testing."""

        def limit(self, *args, **kwargs):
            def decorator(f):
                return f

            return decorator

        def _check_request_limit(self, *args, **kwargs):
            pass

        def _inject_headers(self, *args, **kwargs):
            pass

    limiter = DummyLimiter()
else:
    limiter = Limiter(
        key_func=get_user_or_ip_key,
        storage_uri=_storage_uri,
        default_limits=["200/minute"],
    )
