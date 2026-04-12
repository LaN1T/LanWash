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
                isModifiedByAdmin   INTEGER NOT NULL DEFAULT 0,
                originalPrice       INTEGER NOT NULL DEFAULT 0,
                assignedWasher      TEXT    NOT NULL DEFAULT '',
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

            CREATE TABLE IF NOT EXISTS deleted_notifications (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                username    TEXT NOT NULL,
                createdAt   TEXT NOT NULL
            );

            -- New tables for consumables
            CREATE TABLE IF NOT EXISTS consumables (
                id      TEXT PRIMARY KEY,
                name    TEXT NOT NULL UNIQUE,
                unit    TEXT NOT NULL DEFAULT ''
            );

            CREATE TABLE IF NOT EXISTS service_consumables (
                serviceId         TEXT NOT NULL,
                consumableId      TEXT NOT NULL,
                quantity_per_service REAL NOT NULL,
                PRIMARY KEY (serviceId, consumableId),
                FOREIGN KEY (serviceId) REFERENCES services(id) ON DELETE CASCADE,
                FOREIGN KEY (consumableId) REFERENCES consumables(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS consumable_usage_log (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                appointmentId TEXT    NOT NULL,
                consumableId  TEXT    NOT NULL,
                quantityUsed  REAL    NOT NULL,
                timestamp     TEXT    NOT NULL,
                FOREIGN KEY (appointmentId) REFERENCES appointments(id),
                FOREIGN KEY (consumableId)  REFERENCES consumables(id)
            );

        """)

        # Миграция: таблица deleted_notifications
        await db.execute("""
            CREATE TABLE IF NOT EXISTS deleted_notifications (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                username    TEXT NOT NULL,
                createdAt   TEXT NOT NULL
            )
        """)

        # Миграция: добавить isModifiedByAdmin если колонки нет
        try:
            await db.execute("ALTER TABLE appointments ADD COLUMN isModifiedByAdmin INTEGER NOT NULL DEFAULT 0")
            await db.commit()
        except Exception:
            pass
        try:
            await db.execute("ALTER TABLE appointments ADD COLUMN originalPrice INTEGER NOT NULL DEFAULT 0")
            await db.commit()
        except Exception:
            pass
        try:
            await db.execute("ALTER TABLE appointments ADD COLUMN assignedWasher TEXT NOT NULL DEFAULT ''")
            await db.commit()
        except Exception:
            pass

        # Seed default data if empty
        cursor = await db.execute("SELECT COUNT(*) FROM users")
        count = (await cursor.fetchone())[0]
        if count == 0:
            await _seed(db)

          # Инициализация и авто-обновление расходников
        consumables_list = [
            ("c_shampoo", "Автошампунь", "мл"), ("c_cleaner", "Очиститель салона", "мл"),
            ("c_engine", "Очиститель ДВС", "мл"), ("c_glass_polish", "Паста для стекла", "мл"),
            ("c_antidogd", "Антидождь", "мл"), ("c_wax", "Воск", "мл"),
            ("c_silant", "Силант", "мл"), ("c_ceramic", "Керамика", "мл"),
            ("c_teflon", "Тефлон", "мл"), ("c_bitumen", "Очиститель битума", "мл"),
            ("c_tire_black", "Чернитель шин", "мл"), ("c_vac", "Ресурс пылесоса", "сеанс"),
            ("c_chem", "Химия для химчистки", "мл"), ("c_leather", "Кондиционер для кожи", "мл"),
            ("c_aroma", "Ароматизатор", "мл"), ("c_ozone", "Сеанс озонирования", "сеанс"),
            ("c_polish", "Полировальная паста", "мл"), ("c_anticor", "Антикор", "мл"),
        ]
        for c in consumables_list:
            await db.execute("INSERT OR IGNORE INTO consumables (id, name, unit) VALUES (?,?,?)", c)

        service_links = [
            ("s1", "c_shampoo", 100), ("s2", "c_shampoo", 100), ("s2", "c_cleaner", 150),
            ("s3", "c_shampoo", 50), ("s4", "c_anticor", 1000), ("s5", "c_engine", 200), ("s6", "c_glass_polish", 30),
            ("s7", "c_antidogd", 50), ("s8", "c_wax", 100), ("s9", "c_silant", 50),
            ("s10", "c_ceramic", 30), ("s11", "c_teflon", 50), ("s12", "c_bitumen", 100),
            ("s13", "c_tire_black", 50), ("s14", "c_vac", 1), ("s15", "c_chem", 300),
            ("s16", "c_leather", 100), ("s17", "c_aroma", 10), ("s18", "c_ozone", 1),
            ("s19", "c_polish", 50), ("s20", "c_polish", 50)
        ]
        for link in service_links:
            await db.execute("INSERT OR REPLACE INTO service_consumables (serviceId, consumableId, quantity_per_service) VALUES(?, ?, ?)", link)

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

    # Services
    services = [
        {'id':'s1','name':'Базовая мойка кузова','description':'Предварительная обработка, ручная мойка с профессиональными средствами, полоскание, очистка дисков и арок, сушка.','price':800,'durationMinutes':30,'category':'Мойка кузова','isFavorite':0,'isFromApi':0},
        {'id':'s2','name':'Комплексная мойка + салон','description':'Внешняя мойка кузова плюс полная уборка салона: пылесосная обработка, влажная уборка всех поверхностей, чистка стёкол изнутри.','price':1500,'durationMinutes':60,'category':'Мойка кузова','isFavorite':0,'isFromApi':0},
        {'id':'s3','name':'Экспресс-мойка','description':'Быстрая наружная мойка без детальной обработки. Идеально для поддержания ежедневной чистоты.','price':500,'durationMinutes':15,'category':'Мойка кузова','isFavorite':0,'isFromApi':0},
        {'id':'s4','name':'Обработка арок','description':'Глубокая очистка колесных арок с применением специализированного состава. Удаляет дорожный битум, стойкие загрязнения,'
        'тормозную пыль и реагенты. Предотвращает коррозию металла и придает деталям подвески ухоженный вид.','price':600,'durationMinutes':20,'category':'Специальные услуги','isFavorite':0,'isFromApi':0},
        {'id':'s5','name':'Мойка двигателя','description':'Профессиональная очистка двигательного отсека от масла и грязи.','price':1500,'durationMinutes':60,'category':'Мойка кузова','isFavorite':0,'isFromApi':0},
        {'id':'s6','name':'Полировка стёкол снаружи','description':'Финальная полировка наружных стёкол для максимальной прозрачности и блеска.','price':500,'durationMinutes':20,'category':'Обработка стёкол','isFavorite':0,'isFromApi':0},
        {'id':'s7','name':'Антидождь на стёкла','description':'Нанесение гидрофобного состава на стёкла, обеспечивающего отталкивание воды.','price':600,'durationMinutes':25,'category':'Обработка стёкол','isFavorite':0,'isFromApi':0},
        {'id':'s8','name':'Нанесение защитного воска','description':'Нанесение профессионального защитного воска на кузов для защиты ЛКП.','price':1200,'durationMinutes':45,'category':'Защитные покрытия','isFavorite':0,'isFromApi':0},
        {'id':'s9','name':'Нанесение силанта','description':'Нанесение силантового покрытия для долговременной защиты кузова. Срок действия до 6 месяцев.','price':2000,'durationMinutes':90,'category':'Защитные покрытия','isFavorite':0,'isFromApi':0},
        {'id':'s10','name':'Керамическое покрытие','description':'Профессиональное нанесение керамического покрытия. Максимальная защита ЛКП сроком до 2 лет.','price':15000,'durationMinutes':480,'category':'Защитные покрытия','isFavorite':0,'isFromApi':0},
        {'id':'s11','name':'Нанесение тефлона','description':'Нанесение тефлонового покрытия для защиты кузова и стойкого блеска.','price':3000,'durationMinutes':120,'category':'Защитные покрытия','isFavorite':0,'isFromApi':0},
        {'id':'s12','name':'Удаление битума и смол','description':'Профессиональное удаление следов битума, смолы, насекомых с кузова.','price':700,'durationMinutes':30,'category':'Специальные услуги','isFavorite':0,'isFromApi':0},
        {'id':'s13','name':'Чернение шин','description':'Нанесение специального состава на боковины шин — восстанавливает чёрный цвет и глянцевый блеск.','price':300,'durationMinutes':15,'category':'Специальные услуги','isFavorite':0,'isFromApi':0},
        {'id':'s14','name':'Пылесосная уборка салона','description':'Тщательная пылесосная обработка салона: сиденья, напольные покрытия, багажник.','price':500,'durationMinutes':25,'category':'Уход за салоном','isFavorite':0,'isFromApi':0},
        {'id':'s15','name':'Химчистка салона','description':'Глубокая чистка тканевых и кожаных поверхностей профессиональной химией.','price':3500,'durationMinutes':180,'category':'Уход за салоном','isFavorite':0,'isFromApi':0},
        {'id':'s16','name':'Химчистка кожи','description':'Специализированная очистка и кондиционирование кожаного салона.','price':5000,'durationMinutes':240,'category':'Уход за салоном','isFavorite':0,'isFromApi':0},
        {'id':'s17','name':'Ароматизация салона','description':'Нанесение стойкого ароматизатора. Широкий выбор ароматов.','price':300,'durationMinutes':15,'category':'Уход за салоном','isFavorite':0,'isFromApi':0},
        {'id':'s18','name':'Озонирование салона','description':'Обработка салона озоном для полного устранения запахов и дезинфекции.','price':1000,'durationMinutes':60,'category':'Уход за салоном','isFavorite':0,'isFromApi':0},
        {'id':'s19','name':'Детейлинг кузова','description':'Полный комплекс детальной обработки: полировка кузова, нанесение защитного покрытия.','price':8000,'durationMinutes':360,'category':'Детейлинг','isFavorite':0,'isFromApi':0},
        {'id':'s20','name':'Полировка кузова','description':'Машинная полировка ЛКП для устранения мелких царапин и восстановления блеска.','price':5000,'durationMinutes':240,'category':'Детейлинг','isFavorite':0,'isFromApi':0},
      ]
    for s in services:
        await db.execute(
            "INSERT INTO services (id, name, description, price, durationMinutes, category, isFavorite, isFromApi, updatedAt) VALUES (?,?,?,?,?,?,0,0,?)",
            (s['id'], s['name'], s['description'], s['price'], s['durationMinutes'], s['category'], now),
        )

    # Promos
    promos = [
        ("promo_1", "Акция недели: комплекс + ароматизация", "Комплексная мойка и ароматизация салона по специальной цене недели.", 1600, 75, "Акции"),
        ("promo_2", "Весенняя акция: мойка + воск", "Базовая мойка кузова + нанесение защитного воска. Специальная цена до конца месяца.", 1500, 50, "Акции"),
        ("promo_3", "Выходной пакет: комплексная мойка -20%", "Комплексная мойка кузова со скидкой 20%. Только по выходным — суббота и воскресенье.", 1200, 60, "Акции"),
        ("promo_4", "Пакет для внедорожников", "Полный уход для крупных автомобилей: внедорожников и минивэнов. Тщательная мойка колёс и арок.", 2000, 80, "Акции"),
    ]
    for p in promos:
        await db.execute(
            "INSERT INTO services (id, name, description, price, durationMinutes, category, isFavorite, isFromApi, updatedAt) VALUES(?, ?, ?, ?, ?, ?, 0, 1, ?)",
            (p[0], p[1], p[2], p[3], p[4], p[5], now),
        )

        await db.execute(
            "INSERT INTO promos (id, serviceId, name, description, price, duration, fetchedAt) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (p[0], p[0], p[1], p[2], p[3], p[4], now),
    )

    consumables_list = [
        ("c_shampoo", "Автошампунь", "мл"), ("c_cleaner", "Очиститель салона", "мл"),
        ("c_engine", "Очиститель ДВС", "мл"), ("c_glass_polish", "Паста для стекла", "мл"),
        ("c_antidogd", "Антидождь", "мл"), ("c_wax", "Воск", "мл"),
        ("c_silant", "Силант", "мл"), ("c_ceramic", "Керамика", "мл"),
        ("c_teflon", "Тефлон", "мл"), ("c_bitumen", "Очиститель битума", "мл"),
        ("c_tire_black", "Чернитель шин", "мл"), ("c_vac", "Ресурс пылесоса", "сеанс"),
        ("c_chem", "Химия для химчистки", "мл"), ("c_leather", "Кондиционер для кожи", "мл"),
        ("c_aroma", "Ароматизатор", "мл"), ("c_ozone", "Сеанс озонирования", "сеанс"),
        ("c_polish", "Полировальная паста", "мл"), ("c_anticor", "Антикор", "мл")
    ]
    for c in consumables_list:
        await db.execute("INSERT OR IGNORE INTO consumables (id, name, unit) VALUES (?,?,?)", c)

    service_links = [
        ("s1", "c_shampoo", 100), ("s2", "c_shampoo", 100), ("s2", "c_cleaner", 150),
        ("s3", "c_shampoo", 50), ("s4", "c_anticor", 1000),
        ("s5", "c_engine", 200), ("s6", "c_glass_polish", 30),
        ("s7", "c_antidogd", 50), ("s8", "c_wax", 100), ("s9", "c_silant", 50),
        ("s10", "c_ceramic", 30), ("s11", "c_teflon", 50), ("s12", "c_bitumen", 100),
        ("s13", "c_tire_black", 50), ("s14", "c_vac", 1), ("s15", "c_chem", 300),
        ("s16", "c_leather", 100), ("s17", "c_aroma", 10), ("s18", "c_ozone", 1),
        ("s19", "c_polish", 50), ("s20", "c_polish", 50)
    ]

    for link in service_links:
        await db.execute(
            "INSERT OR REPLACE INTO service_consumables (serviceId, consumableId, quantity_per_service) VALUES(?, ?, ?)",
            link)

    await db.commit()