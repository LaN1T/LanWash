#!/usr/bin/env python3
"""Применить SQL миграцию через asyncpg."""

import asyncio
import asyncpg
import os

async def main():
    url = os.environ.get("DATABASE_URL", "postgresql://lanwash_user:lanwash_password@localhost:5432/lanwash_db")
    # asyncpg не понимает +asyncpg драйвер
    url = url.replace("postgresql+asyncpg://", "postgresql://")
    
    conn = await asyncpg.connect(url)
    
    sql_path = os.path.join(os.path.dirname(__file__), "001_add_missing_columns.sql")
    with open(sql_path) as f:
        sql = f.read()
    
    # Разбиваем по точке с запятой и выполняем каждую команду
    for stmt in sql.split(";"):
        stmt = stmt.strip()
        if stmt and not stmt.startswith("--"):
            print(f"Executing: {stmt[:60]}...")
            await conn.execute(stmt)
    
    await conn.close()
    print("Migration applied successfully.")

if __name__ == "__main__":
    asyncio.run(main())
