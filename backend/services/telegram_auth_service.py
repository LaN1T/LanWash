import time
from datetime import datetime, timedelta, timezone
from typing import Dict, Optional
from urllib.parse import parse_qsl
import hashlib
import hmac
import json

from core.config import get_settings


def verify_telegram_init_data(init_data: str, max_age_seconds: int = 300) -> Optional[Dict]:
    """Verify Telegram WebApp initData signature and freshness.

    Returns parsed user data dict if valid, None otherwise.
    """
    try:
        parsed = dict(parse_qsl(init_data, keep_blank_values=True))
        received_hash = parsed.pop("hash", None)
        if not received_hash:
            return None

        data_check_string = "\n".join(f"{k}={v}" for k, v in sorted(parsed.items()))
        bot_token = get_settings().telegram_bot_token
        if not bot_token:
            return None

        secret_key = hmac.new(
            b"WebAppData", bot_token.encode(), hashlib.sha256
        ).digest()
        computed_hash = hmac.new(
            secret_key, data_check_string.encode(), hashlib.sha256
        ).hexdigest()

        if not hmac.compare_digest(computed_hash, received_hash):
            return None

        auth_date_str = parsed.get("auth_date")
        if not auth_date_str:
            return None
        auth_date = int(auth_date_str)
        now = int(time.time())
        if now - auth_date > max_age_seconds:
            return None

        user_raw = parsed.get("user", "{}")
        return json.loads(user_raw)
    except Exception:
        return None
