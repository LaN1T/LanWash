CREATE TABLE IF NOT EXISTS consumable_usage_log (
    id SERIAL PRIMARY KEY,
    "appointmentId" VARCHAR NOT NULL REFERENCES appointments(id),
    "consumableId" VARCHAR NOT NULL REFERENCES consumables(id),
    "quantityUsed" FLOAT NOT NULL,
    "timestamp" VARCHAR(30) NOT NULL
);
