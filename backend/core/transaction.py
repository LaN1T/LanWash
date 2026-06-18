"""Transaction safety utilities for domain services.

Usage:
    class MyService:
        def __init__(self, db: AsyncSession) -> None:
            self._db = db

        @atomic
        async def create_complex_thing(self, ...):
            # All DB operations here share one transaction.
            # Do NOT call commit() or rollback() inside.
            self._db.add(obj_a)
            self._db.add(obj_b)
            # Auto-committed on success, auto-rolled-back on exception.
"""

from functools import wraps


def atomic(func):
    """Decorator that wraps a service method in ``async with self._db.begin()``.

    The decorated method must belong to a class that has a ``_db: AsyncSession``
    attribute.  Inside the method do **not** call ``commit()``, ``flush()`` or
    ``rollback()`` manually — the context manager handles it.
    """

    @wraps(func)
    async def wrapper(self, *args, **kwargs):
        async with self._db.begin():
            return await func(self, *args, **kwargs)

    return wrapper
