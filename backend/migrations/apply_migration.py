#!/usr/bin/env python3
"""Применить SQL миграцию через asyncpg."""

import asyncio
import asyncpg
import os
import sys

async def main(sql_file: str):
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise RuntimeError("DATABASE_URL environment variable is not set")
    # asyncpg не понимает +asyncpg драйвер
    url = url.replace("postgresql+asyncpg://", "postgresql://")
    
    conn = await asyncpg.connect(url)
    
    sql_path = os.path.join(os.path.dirname(__file__), sql_file)
    with open(sql_path) as f:
        sql = f.read()
    
    # Разбиваем по точке с запятой и выполняем каждую команду
    for stmt in sql.split(";"):
        stmt = stmt.strip()
        if stmt and not stmt.startswith("--"):
            print(f"Executing: {stmt[:60]}...")
            await conn.execute(stmt)
    
    await conn.close()
    print(f"Migration {sql_file} applied successfully.")

if __name__ == "__main__":
    file_name = sys.argv[1] if len(sys.argv) > 1 else "001_add_missing_columns.sql"
    asyncio.run(main(file_name))
