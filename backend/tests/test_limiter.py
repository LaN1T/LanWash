from unittest.mock import MagicMock

import pytest
from core.limiter import get_user_or_ip_key
from fastapi import Request


def test_get_user_or_ip_key_uses_username_for_valid_token():
    import jwt
    from core.config import get_settings

    settings = get_settings()
    token = jwt.encode({"sub": "alice"}, settings.jwt_secret_key, algorithm="HS256")
    request = MagicMock(spec=Request)
    request.headers = {"Authorization": f"Bearer {token}"}
    request.client = MagicMock(host="1.2.3.4")
    assert get_user_or_ip_key(request) == "user:alice"


def test_get_user_or_ip_key_falls_back_to_ip():
    request = MagicMock(spec=Request)
    request.headers = {}
    request.client = MagicMock(host="1.2.3.4")
    assert get_user_or_ip_key(request) == "1.2.3.4"
