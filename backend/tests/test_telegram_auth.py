import time
from urllib.parse import quote
import hashlib
import hmac
import json

import pytest

from core.config import get_settings
from services.telegram_auth_service import verify_telegram_init_data

BOT_TOKEN = "test_token"


@pytest.fixture(autouse=True)
def _patch_bot_token(monkeypatch):
    """Ensure verification uses the same token the tests sign with."""
    monkeypatch.setattr(get_settings(), "telegram_bot_token", BOT_TOKEN)


def _make_init_data(user_id: int, auth_date_offset: int = 0) -> str:
    auth_date = int(time.time()) + auth_date_offset
    user = json.dumps({"id": user_id, "username": "test"})
    # The signature is computed over decoded key/value pairs joined by \n,
    # but initData is transmitted with the user JSON URL-encoded.
    data_check_string = f"auth_date={auth_date}\nuser={user}"
    secret = hmac.new(b"WebAppData", BOT_TOKEN.encode(), hashlib.sha256).digest()
    hash_ = hmac.new(secret, data_check_string.encode(), hashlib.sha256).hexdigest()
    return f"auth_date={auth_date}&user={quote(user)}&hash={hash_}"


def test_verify_init_data_rejects_old_auth_date():
    old = _make_init_data(123, auth_date_offset=-400)
    assert verify_telegram_init_data(old, max_age_seconds=300) is None


def test_verify_init_data_accepts_fresh():
    fresh = _make_init_data(123)
    result = verify_telegram_init_data(fresh, max_age_seconds=300)
    assert result is not None
    assert result["id"] == 123
