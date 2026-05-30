CREATE TABLE IF NOT EXISTS consumable_refill_log (
    id SERIAL PRIMARY KEY,
    "consumableId" VARCHAR NOT NULL REFERENCES consumables(id),
    amount FLOAT NOT NULL,
    "oldStock" FLOAT NOT NULL,
    "newStock" FLOAT NOT NULL,
    "refilledBy" VARCHAR DEFAULT '',
    "timestamp" VARCHAR(30) NOT NULL
);
