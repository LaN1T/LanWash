import jwt
import pytest

from core.config import get_settings
from services.auth_service import (
    create_access_token,
    validate_password_strength,
)

settings = get_settings()


class TestPasswordValidation:
    def test_password_too_short(self):
        result = validate_password_strength("Ab1!")
        assert result is not None
        assert "минимум 8 символов" in result

    def test_password_no_uppercase(self):
        result = validate_password_strength("testpass1!")
        assert result is not None
        assert "заглавную букву" in result

    def test_password_no_lowercase(self):
        result = validate_password_strength("TESTPASS1!")
        assert result is not None
        assert "строчную букву" in result

    def test_password_no_digit(self):
        result = validate_password_strength("TestPass!!")
        assert result is not None
        assert "цифру" in result

    def test_password_no_special(self):
        result = validate_password_strength("TestPass12")
        assert result is not None
        assert "специальный символ" in result

    def test_password_valid(self):
        result = validate_password_strength("TestPass123!")
        assert result is None


class TestJWT:
    def test_create_and_decode_token(self):
        token = create_access_token({"sub": "testuser", "role": "client"})
        assert isinstance(token, str)
        assert len(token) > 0

        payload = jwt.decode(
            token, settings.jwt_secret_key, algorithms=["HS256"]
        )
        assert payload["sub"] == "testuser"
        assert payload["role"] == "client"
        assert "exp" in payload

    def test_token_expiration(self):
        from datetime import timedelta

        token = create_access_token(
            {"sub": "testuser"}, expires_delta=timedelta(seconds=-1)
        )
        with pytest.raises(jwt.ExpiredSignatureError):
            jwt.decode(token, settings.jwt_secret_key, algorithms=["HS256"])
