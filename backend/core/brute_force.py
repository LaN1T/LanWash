"""Brute-force protection for authentication endpoints.

Tracks failed login attempts per IP and per username.
After ``MAX_ATTEMPTS`` failures within ``WINDOW_SECONDS``,
requests are blocked for ``LOCKOUT_SECONDS``.

Uses Redis when available; falls back to an in-memory dict
(single-process only).
"""

import os
import time
from typing import Optional

from core.redis_client import get_redis

MAX_ATTEMPTS = int(os.getenv("BRUTE_FORCE_MAX_ATTEMPTS", "5"))
WINDOW_SECONDS = int(os.getenv("BRUTE_FORCE_WINDOW_SECONDS", "300"))   # 5 min
LOCKOUT_SECONDS = int(os.getenv("BRUTE_FORCE_LOCKOUT_SECONDS", "900"))  # 15 min

_IN_MEMORY: dict[str, list[float]] = {}


def _key(prefix: str, identifier: str) -> str:
    return f"bruteforce:{prefix}:{identifier}"


async def _get_redis_or_none():
    try:
        r = get_redis()
        if r is not None:
            await r.ping()
        return r
    except Exception:
        return None


async def record_failed_attempt(identifier: str) -> int:
    """Record a failed attempt for *identifier* (IP or username).

    Returns the current number of failed attempts within the window.
    """
    redis = await _get_redis_or_none()
    key = _key("attempts", identifier)
    now = time.time()

    if redis:
        pipe = redis.pipeline()
        pipe.zremrangebyscore(key, 0, now - WINDOW_SECONDS)
        pipe.zadd(key, {str(now): now})
        pipe.zcard(key)
        pipe.expire(key, WINDOW_SECONDS + LOCKOUT_SECONDS)
        _, _, count, _ = await pipe.execute()
        return count

    # In-memory fallback
    attempts = _IN_MEMORY.setdefault(key, [])
    cutoff = now - WINDOW_SECONDS
    attempts[:] = [t for t in attempts if t > cutoff]
    attempts.append(now)
    return len(attempts)


async def is_locked_out(identifier: str) -> bool:
    """Return ``True`` if *identifier* is currently locked out."""
    redis = await _get_redis_or_none()
    key = _key("attempts", identifier)
    now = time.time()

    if redis:
        await redis.zremrangebyscore(key, 0, now - WINDOW_SECONDS)
        count = await redis.zcard(key)
        return count >= MAX_ATTEMPTS

    attempts = _IN_MEMORY.get(key, [])
    cutoff = now - WINDOW_SECONDS
    attempts[:] = [t for t in attempts if t > cutoff]
    if not attempts:
        _IN_MEMORY.pop(key, None)
    return len(attempts) >= MAX_ATTEMPTS


async def reset_attempts(identifier: str) -> None:
    """Clear failed attempts for *identifier* (e.g. after successful login)."""
    redis = await _get_redis_or_none()
    key = _key("attempts", identifier)

    if redis:
        await redis.delete(key)
    else:
        _IN_MEMORY.pop(key, None)


async def check_and_record(identifier: str) -> Optional[int]:
    """High-level helper: check lockout, record attempt, return remaining attempts.

    Returns ``None`` if not locked out (attempt was recorded).
    Returns ``0`` if locked out.
    """
    if await is_locked_out(identifier):
        return 0
    count = await record_failed_attempt(identifier)
    remaining = max(0, MAX_ATTEMPTS - count)
    if remaining == 0:
        return 0
    return remaining
