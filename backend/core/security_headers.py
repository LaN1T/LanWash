"""Security headers middleware.

Adds CSP, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy,
and Permissions-Policy to every HTTP response.
"""

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp

# Strict CSP for API + Flutter web.  Disables inline scripts/styles
# except for self origin.  Images/media can come from anywhere (needed
# for avatars / uploaded photos).  Connect-src allows API calls and
# WebSocket upgrades.
_CSP = (
    "default-src 'self'; "
    "script-src 'self'; "
    "style-src 'self' 'unsafe-inline'; "
    "img-src 'self' data: blob: *; "
    "font-src 'self' data:; "
    "connect-src 'self' ws: wss:; "
    "media-src 'self' blob: *; "
    "frame-ancestors 'none'; "
    "base-uri 'self'; "
    "form-action 'self';"
)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: ASGIApp, csp: str = _CSP) -> None:
        super().__init__(app)
        self._csp = csp

    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = (
            "accelerometer=(), camera=(), geolocation=(), gyroscope=(), "
            "magnetometer=(), microphone=(), payment=(), usb=()"
        )
        response.headers["Content-Security-Policy"] = self._csp
        # HSTS — only over HTTPS in production; harmless header over HTTP
        response.headers["Strict-Transport-Security"] = "max-age=63072000; includeSubDomains"
        return response
