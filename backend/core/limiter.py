import ipaddress
import os

from fastapi import Request
from slowapi import Limiter


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
            # Take the first (closest to client) IP
            return x_forwarded_for.split(",")[0].strip()
        x_real_ip = request.headers.get("X-Real-IP")
        if x_real_ip:
            return x_real_ip
    if direct_host:
        return direct_host
    return "127.0.0.1"


# Use Redis for rate limiting in production (multi-worker safe).
# Fallback to in-memory storage if REDIS_URL is not set.
_redis_url = os.getenv("REDIS_URL")
_storage_uri = _redis_url if _redis_url else "memory://"

if os.getenv("DISABLE_RATE_LIMIT") == "true":
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
        key_func=get_proxy_aware_remote_address,
        storage_uri=_storage_uri,
        default_limits=["200/minute"],
    )
