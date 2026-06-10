import hashlib
import hmac
import json
from typing import Dict, Optional
from urllib.parse import parse_qsl

from core.config import get_settings

settings = get_settings()


def verify_telegram_init_data(init_data: str) -> Optional[Dict]:
    """
    Verify Telegram WebApp initData signature.
    Returns parsed user data dict if valid, None if invalid.
    """
    try:
        parsed = dict(parse_qsl(init_data, keep_blank_values=True))
        received_hash = parsed.pop("hash", None)
        if not received_hash:
            return None

        # Sort by key and join with newlines
        data_check_string = "\n".join(
            f"{k}={v}" for k, v in sorted(parsed.items())
        )

        bot_token = settings.telegram_bot_token
        if not bot_token:
            return None

        # Secret key = HMAC-SHA256("WebAppData", bot_token)
        secret_key = hmac.new(
            b"WebAppData",
            bot_token.encode(),
            hashlib.sha256,
        ).digest()

        # Compute hash
        computed_hash = hmac.new(
            secret_key,
            data_check_string.encode(),
            hashlib.sha256,
        ).hexdigest()

        if not hmac.compare_digest(computed_hash, received_hash):
            return None

        # Parse user JSON
        user_raw = parsed.get("user", "{}")
        user = json.loads(user_raw)
        return user
    except Exception:
        return None
