-- Миграция: добавление недостающих колонок и таблиц
-- Применить: docker exec -i lanwash_postgres psql -U lanwash_user -d lanwash_db < backend/migrations/001_add_missing_columns.sql

ALTER TABLE users ADD COLUMN IF NOT EXISTS "avatarUrl" VARCHAR DEFAULT '';

ALTER TABLE consumables ADD COLUMN IF NOT EXISTS "currentStock" FLOAT DEFAULT 0.0;
ALTER TABLE consumables ADD COLUMN IF NOT EXISTS "minStock" FLOAT DEFAULT 0.0;

CREATE TABLE IF NOT EXISTS shifts (
    id SERIAL PRIMARY KEY,
    "userId" INTEGER NOT NULL REFERENCES users(id),
    date VARCHAR(10) NOT NULL,
    "startTime" VARCHAR(5) NOT NULL,
    "endTime" VARCHAR(5) NOT NULL,
    status VARCHAR(20) DEFAULT 'confirmed',
    "createdBy" VARCHAR(50) NOT NULL,
    "createdAt" VARCHAR(30) NOT NULL,
    "updatedAt" VARCHAR(30) NOT NULL
);
