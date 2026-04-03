import aiosqlite
import hashlib
import os
from datetime import datetime

DB_PATH = os.getenv("DB_PATH", os.path.join(os.path.dirname(__file__), "lanwash.db"))


def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()


async def get_db() -> aiosqlite.Connection:
    db = await aiosqlite.connect(DB_PATH)
    db.row_factory = aiosqlite.Row
    await db.execute("PRAGMA foreign_keys = ON")
    return db


async def init_db():
    db = await get_db()
    try:
        await db.executescript("""
            CREATE TABLE IF NOT EXISTS users (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                username      TEXT    NOT NULL UNIQUE,
                passwordHash  TEXT    NOT NULL,
                role          TEXT    NOT NULL DEFAULT 'client',
                displayName   TEXT    NOT NULL,
                phone         TEXT    NOT NULL DEFAULT '',
                carModel      TEXT    NOT NULL DEFAULT '',
                carNumber     TEXT    NOT NULL DEFAULT '',
                createdAt     TEXT    NOT NULL,
                isFavoriteAdmin INTEGER NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS appointments (
                id                  TEXT    PRIMARY KEY,
                userId              INTEGER,
                clientName          TEXT    NOT NULL,
                carModel            TEXT    NOT NULL,
                carNumber           TEXT    NOT NULL,
                dateTime            TEXT    NOT NULL,
                washType            TEXT    NOT NULL,
                additionalServices  TEXT    NOT NULL DEFAULT '[]',
                status              TEXT    NOT NULL DEFAULT 'scheduled',
                notes               TEXT    NOT NULL DEFAULT '',
                isFavorite          INTEGER NOT NULL DEFAULT 0,
                ownerUsername       TEXT    NOT NULL DEFAULT '',
                promoPrice          INTEGER NOT NULL DEFAULT 0,
                paidPrice           INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY (userId) REFERENCES users(id) ON DELETE SET NULL
            );

            CREATE TABLE IF NOT EXISTS services (
                id              TEXT    PRIMARY KEY,
                name            TEXT    NOT NULL,
                description     TEXT    NOT NULL DEFAULT '',
                price           INTEGER NOT NULL DEFAULT 0,
                durationMinutes INTEGER NOT NULL DEFAULT 30,
                category        TEXT    NOT NULL DEFAULT '',
                isFavorite      INTEGER NOT NULL DEFAULT 0,
                isFromApi       INTEGER NOT NULL DEFAULT 0,
                updatedAt       TEXT    NOT NULL
            );

            CREATE TABLE IF NOT EXISTS promos (
                id          TEXT    PRIMARY KEY,
                serviceId   TEXT    NOT NULL,
                name        TEXT    NOT NULL,
                description TEXT    NOT NULL DEFAULT '',
                price       INTEGER NOT NULL DEFAULT 0,
                duration    INTEGER NOT NULL DEFAULT 30,
                fetchedAt   TEXT    NOT NULL,
                FOREIGN KEY (serviceId) REFERENCES services(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS logs (
                id        INTEGER PRIMARY KEY AUTOINCREMENT,
                username  TEXT NOT NULL,
                action    TEXT NOT NULL,
                details   TEXT NOT NULL DEFAULT '',
                timestamp TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS service_favorites (
                username  TEXT NOT NULL,
                serviceId TEXT NOT NULL,
                PRIMARY KEY (username, serviceId)
            );

            CREATE TABLE IF NOT EXISTS extra_favorites (
                username    TEXT NOT NULL,
                serviceName TEXT NOT NULL,
                PRIMARY KEY (username, serviceName)
            );

            CREATE TABLE IF NOT EXISTS washer_notes (
                id        INTEGER PRIMARY KEY AUTOINCREMENT,
                username  TEXT    NOT NULL,
                title     TEXT    NOT NULL,
                message   TEXT    NOT NULL DEFAULT '',
                category  TEXT    NOT NULL DEFAULT 'general',
                isRead    INTEGER NOT NULL DEFAULT 0,
                createdAt TEXT    NOT NULL
            );

            CREATE TABLE IF NOT EXISTS consumables (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                mechanicName  TEXT    NOT NULL,
                item          TEXT    NOT NULL,
                quantity      TEXT    NOT NULL,
                telegramId    INTEGER NOT NULL DEFAULT 0,
                createdAt     TEXT    NOT NULL
            );
        """)

        # Seed default data if empty
        cursor = await db.execute("SELECT COUNT(*) FROM users")
        count = (await cursor.fetchone())[0]
        if count == 0:
            await _seed(db)

        await db.commit()
    finally:
        await db.close()


async def _seed(db: aiosqlite.Connection):
    now = datetime.now().isoformat()

    # Default users
    await db.execute(
        "INSERT INTO users (username, passwordHash, role, displayName, phone, carModel, carNumber, createdAt, isFavoriteAdmin) VALUES (?,?,?,?,?,?,?,?,?)",
        ("admin", hash_password("admin"), "admin", "Администратор", "", "", "", now, 0),
    )
    await db.execute(
        "INSERT INTO users (username, passwordHash, role, displayName, phone, carModel, carNumber, createdAt, isFavoriteAdmin) VALUES (?,?,?,?,?,?,?,?,?)",
        ("client", hash_password("1234"), "client", "client", "", "", "", now, 0),
    )
    await db.execute(
        "INSERT INTO users (username, passwordHash, role, displayName, phone, carModel, carNumber, createdAt, isFavoriteAdmin) VALUES (?,?,?,?,?,?,?,?,?)",
        ("washer", hash_password("washer"), "washer", "Мойщик", "", "", "", now, 0),
    )

    # Services
    services = [
        ("s1", "Базовая мойка кузова", "Предварительная обработка, ручная мойка с профессиональными средствами, полоскание, очистка дисков и арок, сушка.", 800, 30, "Мойка кузова"),
        ("s2", "Комплексная мойка + салон", "Внешняя мойка кузова плюс полная уборка салона: пылесосная обработка, влажная уборка всех поверхностей, чистка стёкол изнутри.", 1500, 60, "Мойка кузова"),
        ("s3", "Экспресс-мойка", "Быстрая наружная мойка без детальной обработки. Идеально для поддержания ежедневной чистоты.", 500, 15, "Мойка кузова"),
        ("s4", "Мойка с активной пеной", "Мойка кузова с применением активной пены и профессиональной химии для стойких загрязнений.", 1100, 45, "Мойка кузова"),
        ("s5", "Очистка колёсных дисков", "Специализированная чистка дисков от тормозной пыли и нагара.", 400, 20, "Мойка кузова"),
        ("s6", "Мойка двигателя", "Профессиональная очистка двигательного отсека от масла и грязи.", 1500, 60, "Мойка кузова"),
        ("s7", "Полировка стёкол снаружи", "Финальная полировка наружных стёкол для максимальной прозрачности и блеска.", 500, 20, "Обработка стёкол"),
        ("s8", "Антидождь на стёкла", "Нанесение гидрофобного состава на стёкла, обеспечивающего отталкивание воды.", 600, 25, "Обработка стёкол"),
        ("s9", "Нанесение защитного воска", "Нанесение профессионального защитного воска на кузов для защиты ЛКП.", 1200, 45, "Защитные покрытия"),
        ("s10", "Нанесение силанта", "Нанесение силантового покрытия для долговременной защиты кузова. Срок действия до 6 месяцев.", 2000, 90, "Защитные покрытия"),
        ("s11", "Керамическое покрытие", "Профессиональное нанесение керамического покрытия. Максимальная защита ЛКП сроком до 2 лет.", 15000, 480, "Защитные покрытия"),
        ("s12", "Нанесение тефлона", "Нанесение тефлонового покрытия для защиты кузова и стойкого блеска.", 3000, 120, "Защитные покрытия"),
        ("s13", "Удаление битума и смол", "Профессиональное удаление следов битума, смолы, насекомых с кузова.", 700, 30, "Специальные услуги"),
        ("s14", "Чернение шин", "Нанесение специального состава на боковины шин — восстанавливает чёрный цвет и глянцевый блеск.", 300, 15, "Специальные услуги"),
        ("s15", "Пылесосная уборка салона", "Тщательная пылесосная обработка салона: сиденья, напольные покрытия, багажник.", 500, 25, "Уход за салоном"),
        ("s16", "Влажная уборка салона", "Обработка всех поверхностей салона специализированными средствами.", 800, 40, "Уход за салоном"),
        ("s17", "Химчистка салона", "Глубокая чистка тканевых и кожаных поверхностей профессиональной химией.", 3500, 180, "Уход за салоном"),
        ("s18", "Химчистка кожи", "Специализированная очистка и кондиционирование кожаного салона.", 5000, 240, "Уход за салоном"),
        ("s19", "Ароматизация салона", "Нанесение стойкого ароматизатора. Широкий выбор ароматов.", 300, 15, "Уход за салоном"),
        ("s20", "Озонирование салона", "Обработка салона озоном для полного устранения запахов и дезинфекции.", 1000, 60, "Уход за салоном"),
        ("s21", "Детейлинг кузова", "Полный комплекс детальной обработки: полировка кузова, нанесение защитного покрытия.", 8000, 360, "Детейлинг"),
        ("s22", "Полировка кузова", "Машинная полировка ЛКП для устранения мелких царапин и восстановления блеска.", 5000, 240, "Детейлинг"),
    ]
    for s in services:
        await db.execute(
            "INSERT INTO services (id, name, description, price, durationMinutes, category, isFavorite, isFromApi, updatedAt) VALUES (?,?,?,?,?,?,0,0,?)",
            (*s, now),
        )

    # Promos
    promos = [
        ("promo_1", "Акция недели: комплекс + ароматизация", "Комплексная мойка и ароматизация салона по специальной цене недели.", 1600, 75, "Акции"),
        ("promo_2", "Весенняя акция: мойка + воск", "Базовая мойка кузова + нанесение защитного воска. Специальная цена до конца месяца.", 1500, 50, "Акции"),
        ("promo_3", "Выходной пакет: комплексная мойка -20%", "Комплексная мойка кузова со скидкой 20%. Только по выходным — суббота и воскресенье.", 1100, 60, "Акции"),
        ("promo_4", "Пакет для внедорожников", "Полный уход для крупных автомобилей: внедорожников и минивэнов. Тщательная мойка колёс и арок.", 2000, 80, "Акции"),
    ]
    for p in promos:
        await db.execute(
            "INSERT INTO services (id, name, description, price, durationMinutes, category, isFavorite, isFromApi, updatedAt) VALUES (?,?,?,?,?,?,0,1,?)",
            (*p, now),
        )
        await db.execute(
            "INSERT INTO promos (id, serviceId, name, description, price, duration, fetchedAt) VALUES (?,?,?,?,?,?,?)",
            (p[0], p[0], p[1], p[2], p[3], p[4], now),
        )
