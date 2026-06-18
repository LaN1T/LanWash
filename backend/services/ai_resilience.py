"""Rate limiting, caching, and circuit breaker for AI calls."""

import asyncio
import hashlib
import time
from collections import deque
from typing import Optional

import structlog

logger = structlog.get_logger()


class SlidingWindowLimiter:
    """Thread-safe (async) sliding window rate limiter."""

    def __init__(self, max_requests: int, window_seconds: float) -> None:
        self.max_requests = max_requests
        self.window = window_seconds
        self._requests: deque[float] = deque()
        self._lock = asyncio.Lock()

    async def acquire(self) -> bool:
        now = time.monotonic()
        async with self._lock:
            # Evict old entries outside the window
            while self._requests and self._requests[0] < now - self.window:
                self._requests.popleft()
            if len(self._requests) < self.max_requests:
                self._requests.append(now)
                return True
            return False

    async def state(self) -> dict:
        now = time.monotonic()
        async with self._lock:
            while self._requests and self._requests[0] < now - self.window:
                self._requests.popleft()
            return {
                "used": len(self._requests),
                "limit": self.max_requests,
                "window_seconds": self.window,
            }


class AICache:
    """Simple in-memory cache for AI responses with TTL and bounded size."""

    def __init__(self, ttl_seconds: float = 300.0, max_size: int = 1000) -> None:
        self.ttl = ttl_seconds
        self.max_size = max_size
        self._store: dict[str, tuple[str, float]] = {}
        self._lock = asyncio.Lock()

    @staticmethod
    def _key(system: str, user: str) -> str:
        return hashlib.sha256(f"{system}:{user}".encode()).hexdigest()[:32]

    async def get(self, system: str, user: str) -> Optional[str]:
        key = self._key(system, user)
        now = time.monotonic()
        async with self._lock:
            entry = self._store.get(key)
            if not entry:
                return None
            value, expiry = entry
            if now < expiry:
                logger.debug("ai_cache_hit")
                return value
            del self._store[key]
            return None

    async def set(self, system: str, user: str, value: str) -> None:
        key = self._key(system, user)
        async with self._lock:
            self._store[key] = (value, time.monotonic() + self.ttl)
            # Evict oldest entries if cache exceeds max size
            while len(self._store) > self.max_size:
                self._store.pop(next(iter(self._store)), None)
            # Also evict expired entries opportunistically
            now = time.monotonic()
            expired = [k for k, (_, expiry) in self._store.items() if expiry <= now]
            for k in expired:
                self._store.pop(k, None)

    async def clear(self) -> None:
        async with self._lock:
            self._store.clear()


class CircuitBreaker:
    """Simple circuit breaker for external AI API."""

    def __init__(
        self,
        failure_threshold: int = 5,
        recovery_timeout: float = 60.0,
    ) -> None:
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self._failures = 0
        self._last_failure = 0.0
        self._state = "closed"  # closed | open | half_open
        self._lock = asyncio.Lock()

    async def can_execute(self) -> bool:
        now = time.monotonic()
        async with self._lock:
            if self._state == "closed":
                return True
            if self._state == "open":
                if now - self._last_failure > self.recovery_timeout:
                    self._state = "half_open"
                    return True
                return False
            # half_open
            return True

    async def record_success(self) -> None:
        async with self._lock:
            self._failures = 0
            self._state = "closed"

    async def record_failure(self, is_rate_limit: bool = False) -> None:
        async with self._lock:
            self._failures += 1
            self._last_failure = time.monotonic()
            if is_rate_limit or self._failures >= self.failure_threshold:
                self._state = "open"
                logger.warning(
                    "circuit_breaker_opened",
                    failures=self._failures,
                    is_rate_limit=is_rate_limit,
                )

    async def state(self) -> dict:
        async with self._lock:
            return {
                "state": self._state,
                "failures": self._failures,
                "last_failure": self._last_failure,
            }


# Global instances (single-process; for multi-process use Redis)
_minute_limiter = SlidingWindowLimiter(max_requests=25, window_seconds=60.0)
_day_limiter = SlidingWindowLimiter(max_requests=800, window_seconds=86400.0)
_response_cache = AICache(ttl_seconds=300.0)
_groq_breaker = CircuitBreaker(failure_threshold=5, recovery_timeout=60.0)


async def ai_rate_limit_ok() -> bool:
    """Check both per-minute and per-day limits."""
    minute_ok = await _minute_limiter.acquire()
    if not minute_ok:
        logger.warning("ai_rate_limit_minute_exceeded")
        return False
    day_ok = await _day_limiter.acquire()
    if not day_ok:
        logger.warning("ai_rate_limit_day_exceeded")
        return False
    return True


async def ai_cache_get(system: str, user: str) -> Optional[str]:
    return await _response_cache.get(system, user)


async def ai_cache_set(system: str, user: str, value: str) -> None:
    await _response_cache.set(system, user, value)


async def ai_circuit_breaker_ok() -> bool:
    return await _groq_breaker.can_execute()


async def ai_record_success() -> None:
    await _groq_breaker.record_success()


async def ai_record_failure(is_rate_limit: bool = False) -> None:
    await _groq_breaker.record_failure(is_rate_limit=is_rate_limit)


async def ai_health() -> dict:
    return {
        "minute_limiter": await _minute_limiter.state(),
        "day_limiter": await _day_limiter.state(),
        "circuit_breaker": await _groq_breaker.state(),
        "cache_keys": len(_response_cache._store),
    }
