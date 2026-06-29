import time
import urllib.parse
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


def test_verify_init_data_rejects_invalid_signature():
    fresh = _make_init_data(123)
    tampered = fresh.replace("user=", "user=1")
    assert verify_telegram_init_data(tampered, max_age_seconds=300) is None


def test_verify_init_data_rejects_missing_hash():
    fresh = _make_init_data(123)
    missing_hash = "&".join(p for p in fresh.split("&") if not p.startswith("hash="))
    assert verify_telegram_init_data(missing_hash, max_age_seconds=300) is None


def test_verify_init_data_rejects_missing_auth_date():
    fresh = _make_init_data(123)
    missing_date = "&".join(
        p for p in fresh.split("&") if not p.startswith("auth_date=")
    )
    assert verify_telegram_init_data(missing_date, max_age_seconds=300) is None


def test_verify_init_data_rejects_malformed_user_json():
    auth_date = int(time.time())
    bad_user = "{bad"
    data_check_string = f"auth_date={auth_date}\nuser={bad_user}"
    secret = hmac.new(b"WebAppData", BOT_TOKEN.encode(), hashlib.sha256).digest()
    hash_ = hmac.new(secret, data_check_string.encode(), hashlib.sha256).hexdigest()
    malformed = f"auth_date={auth_date}&user={urllib.parse.quote(bad_user)}&hash={hash_}"
    assert verify_telegram_init_data(malformed, max_age_seconds=300) is None


def test_verify_init_data_rejects_future_auth_date():
    future = _make_init_data(123, auth_date_offset=400)
    assert verify_telegram_init_data(future, max_age_seconds=300) is None


def test_verify_init_data_rejects_empty_init_data():
    assert verify_telegram_init_data("", max_age_seconds=300) is None
