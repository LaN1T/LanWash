def test_sentry_dsn_config():
    from core.config import get_settings

    settings = get_settings()
    assert hasattr(settings, "sentry_dsn")
