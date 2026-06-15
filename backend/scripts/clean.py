#!/usr/bin/env python3
"""Drop and recreate the lanwash_test database for clean load testing."""

import asyncio
import os
import sys

# Ensure backend is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine


def get_admin_url():
    """Build admin connection URL (connects to 'postgres' db to manage lanwash_test)."""
    base = os.getenv("DATABASE_URL", "postgresql+asyncpg://lanwash_user:password@localhost:5432/lanwash_db")
    # Replace any db name with 'postgres' for admin operations
    if "://" in base:
        scheme, rest = base.split("://", 1)
        if "@" in rest:
            auth_host, db_part = rest.rsplit("/", 1)
            # Remove query params if any
            _ = db_part.split("?")[0]
            return f"{scheme}://{auth_host}/postgres"
    return "postgresql+asyncpg://lanwash_user:password@localhost:5432/postgres"


def get_test_url():
    """Build test database URL."""
    base = os.getenv("DATABASE_URL", "postgresql+asyncpg://lanwash_user:password@localhost:5432/lanwash_db")
    if "://" in base:
        scheme, rest = base.split("://", 1)
        if "@" in rest:
            auth_host, _ = rest.rsplit("/", 1)
            return f"{scheme}://{auth_host}/lanwash_test"
    return "postgresql+asyncpg://lanwash_user:password@localhost:5432/lanwash_test"


async def drop_and_recreate():
    admin_url = get_admin_url()
    test_url = get_test_url()

    print(f"Admin URL: {admin_url}")
    print(f"Test URL:  {test_url}")

    # 1. Connect to postgres db as admin
    admin_engine = create_async_engine(admin_url, echo=False, isolation_level="AUTOCOMMIT")
    try:
        async with admin_engine.connect() as conn:
            # Terminate existing connections to lanwash_test
            await conn.execute(text("""
                SELECT pg_terminate_backend(pid)
                FROM pg_stat_activity
                WHERE datname = 'lanwash_test' AND pid <> pg_backend_pid()
            """))
            await conn.execute(text("DROP DATABASE IF EXISTS lanwash_test"))
            await conn.execute(text("CREATE DATABASE lanwash_test"))
            print("✅ Database lanwash_test recreated")
    except Exception as e:
        print(f"⚠️  DROP/CREATE failed ({e}), falling back to TRUNCATE...")
        # Fallback: connect to lanwash_test and truncate all tables
        test_engine = create_async_engine(test_url, echo=False)
        async with test_engine.connect() as conn:
            await conn.execute(text("""
                DO $$ DECLARE
                    r RECORD;
                BEGIN
                    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
                        EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.tablename) || ' CASCADE';
                    END LOOP;
                END $$;
            """))
            await conn.commit()
            print("✅ All tables truncated")
        await test_engine.dispose()
    finally:
        await admin_engine.dispose()

    # 2. Init schema + seed base data (wash types, services, consumables, promos)
    print("🔄 Creating tables and seeding base data...")
    os.environ["DATABASE_URL"] = test_url

    # Re-import after setting env var
    from db.init import init_db

    await init_db()
    print("✅ Tables + base data ready")


if __name__ == "__main__":
    asyncio.run(drop_and_recreate())
