"""Password hashing/verification helpers.

Uses bcrypt for new hashes (fast, no heavy memory requirements) and keeps
argon2 verification for existing hashes created during the argon2-only phase.
"""

import bcrypt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

_argon2_hasher = PasswordHasher()


def hash_password(password: str) -> str:
    """Hash a password with bcrypt."""
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode(
        "utf-8"
    )


def verify_password(password: str, hashed: str) -> bool:
    """Verify a password against a bcrypt or argon2 hash."""
    if not hashed:
        return False

    password_bytes = password.encode("utf-8")

    if hashed.startswith("$2"):
        # bcrypt rejects secrets longer than 72 bytes; replicate passlib's
        # legacy truncate-at-72-bytes behaviour so older hashes still verify.
        try:
            return bcrypt.checkpw(password_bytes[:72], hashed.encode("utf-8"))
        except ValueError:
            return False

    if hashed.startswith("$argon2"):
        try:
            _argon2_hasher.verify(hashed, password)
            return True
        except VerifyMismatchError:
            return False

    return False
