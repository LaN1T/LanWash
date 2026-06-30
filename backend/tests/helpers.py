"""Test helpers shared across the backend test suite."""

import uuid as _uuid_module


class _FakeUUID:
    """Lightweight UUID stand-in that only needs to support ``str()``."""

    def __init__(self, value: str):
        self._value = value

    def __str__(self) -> str:
        return self._value

    def __repr__(self) -> str:
        return f"FakeUUID({self._value!r})"


_next_uuid_id: str | None = None
_orig_uuid4 = _uuid_module.uuid4


def _patched_uuid4():
    """Return a deterministic ID when set, otherwise fall back to real UUID4."""
    global _next_uuid_id
    if _next_uuid_id is not None:
        val = _next_uuid_id
        _next_uuid_id = None
        return _FakeUUID(val)
    return _orig_uuid4()


def set_next_uuid(uid: str) -> None:
    """Make the next ``uuid.uuid4()`` call return ``uid`` as its string value."""
    global _next_uuid_id
    _next_uuid_id = uid


def clear_next_uuid() -> None:
    global _next_uuid_id
    _next_uuid_id = None
