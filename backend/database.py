import os
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select, func
from sqlalchemy.dialects.postgresql import insert
from backend.db_models import (
    Base, User, Service, Consumable, ServiceConsumable, Promo,
    WashType, WashTypeIncludedExtra, WashTypeConsumable, PromoIncludedExtra,
)
from datetime import datetime
import hashlib

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+asyncpg://lanwash_user:lanwash_password@localhost:5432/lanwash_db")

engine = create_async_engine(DATABASE_URL, echo=True)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await seed_data()

async def seed_data():
    async with AsyncSessionLocal() as session:
        now = datetime.now().isoformat()

        # Admin User (Upsert)
        stmt = insert(User).values(
            username="admin", passwordHash=hash_password("admin"), role="admin",
            displayName="Администратор", createdAt=now
        ).on_conflict_do_nothing(index_elements=['username'])
        await session.execute(stmt)
        await session.commit()

        # Wash Types
        res = await session.execute(select(func.count(WashType.id)))
        if res.scalar() == 0:
            session.add_all([
                WashType(id='w1', code='express', name='Экспресс-мойка',
                    description='Быстрая наружная мойка без детальной обработки. Идеально для поддержания ежедневной чистоты.',
                    basePrice=500, durationMinutes=15, sortOrder=1),
                WashType(id='w2', code='basic', name='Базовая мойка',
                    description='Активная пена, тщательная ручная очистка и финальное ополаскивание с сушкой.',
                    basePrice=800, durationMinutes=30, sortOrder=2),
                WashType(id='w3', code='complex', name='Комплексная мойка',
                    description='Базовая мойка плюс уборка салона, пылесос, чистка стёкол.',
                    basePrice=1500, durationMinutes=60, sortOrder=3),
                WashType(id='w4', code='premium', name='Премиум мойка',
                    description='Комплексная мойка плюс уход за пластиком, резиной и ароматизация.',
                    basePrice=3000, durationMinutes=90, sortOrder=4),
            ])
            await session.commit()

        # Services (только доп.услуги, без типов мойки)
        res = await session.execute(select(func.count(Service.id)))
        if res.scalar() == 0:
            services = [
                Service(id='s4', name='Обработка арок', description='Глубокая очистка колесных арок с применением специализированного состава. Удаляет дорожный битум, стойкие загрязнения, тормозную пыль и реагенты.', price=600, durationMinutes=20, category='Специальные услуги', updatedAt=now),
                Service(id='s5', name='Мойка двигателя', description='Профессиональная очистка двигательного отсека от масла и грязи.', price=1500, durationMinutes=60, category='Специальные услуги', updatedAt=now),
                Service(id='s6', name='Полировка стёкол', description='Финальная полировка наружных стёкол для максимальной прозрачности и блеска.', price=500, durationMinutes=20, category='Обработка стёкол', updatedAt=now),
                Service(id='s7', name='Антидождь', description='Нанесение гидрофобного состава на стёкла, обеспечивающего отталкивание воды.', price=600, durationMinutes=25, category='Обработка стёкол', updatedAt=now),
                Service(id='s8', name='Нанесение воска', description='Нанесение профессионального защитного воска на кузов для защиты ЛКП.', price=1200, durationMinutes=45, category='Защитные покрытия', updatedAt=now),
                Service(id='s9', name='Нанесение силанта', description='Нанесение силантового покрытия для долговременной защиты кузова. Срок действия до 6 месяцев.', price=2000, durationMinutes=90, category='Защитные покрытия', updatedAt=now),
                Service(id='s10', name='Керамическое покрытие', description='Профессиональное нанесение керамического покрытия. Максимальная защита ЛКП сроком до 2 лет.', price=15000, durationMinutes=480, category='Защитные покрытия', updatedAt=now),
                Service(id='s11', name='Нанесение тефлона', description='Нанесение тефлонового покрытия для защиты кузова и стойкого блеска.', price=3000, durationMinutes=120, category='Защитные покрытия', updatedAt=now),
                Service(id='s12', name='Удаление битума', description='Профессиональное удаление следов битума, смолы, насекомых с кузова.', price=700, durationMinutes=30, category='Специальные услуги', updatedAt=now),
                Service(id='s13', name='Чернение шин', description='Нанесение специального состава на боковины шин — восстанавливает чёрный цвет и глянцевый блеск.', price=300, durationMinutes=15, category='Специальные услуги', updatedAt=now),
                Service(id='s14', name='Пылесосная уборка', description='Тщательная пылесосная обработка салона: сиденья, напольные покрытия, багажник.', price=500, durationMinutes=25, category='Уход за салоном', updatedAt=now),
                Service(id='s15', name='Химчистка салона', description='Глубокая чистка тканевых и кожаных поверхностей профессиональной химией.', price=3500, durationMinutes=180, category='Уход за салоном', updatedAt=now),
                Service(id='s16', name='Химчистка кожи', description='Специализированная очистка и кондиционирование кожаного салона.', price=5000, durationMinutes=240, category='Уход за салоном', updatedAt=now),
                Service(id='s17', name='Ароматизация', description='Нанесение стойкого ароматизатора. Широкий выбор ароматов.', price=300, durationMinutes=15, category='Уход за салоном', updatedAt=now),
                Service(id='s18', name='Озонирование', description='Обработка салона озоном для полного устранения запахов и дезинфекции.', price=1000, durationMinutes=60, category='Уход за салоном', updatedAt=now),
                Service(id='s19', name='Детейлинг кузова', description='Полный комплекс детальной обработки: полировка кузова, нанесение защитного покрытия.', price=8000, durationMinutes=360, category='Детейлинг', updatedAt=now),
                Service(id='s20', name='Полировка кузова', description='Машинная полировка ЛКП для устранения мелких царапин и восстановления блеска.', price=5000, durationMinutes=240, category='Детейлинг', updatedAt=now),
            ]
            session.add_all(services)
            await session.flush()

            # Consumables
            session.add_all([
                Consumable(id="c_shampoo", name="Автошампунь", unit="мл"),
                Consumable(id="c_cleaner", name="Очиститель салона", unit="мл"),
                Consumable(id="c_engine", name="Очиститель ДВС", unit="мл"),
                Consumable(id="c_glass_polish", name="Паста для стекла", unit="мл"),
                Consumable(id="c_antidogd", name="Антидождь", unit="мл"),
                Consumable(id="c_wax", name="Воск", unit="мл"),
                Consumable(id="c_silant", name="Силант", unit="мл"),
                Consumable(id="c_ceramic", name="Керамика", unit="мл"),
                Consumable(id="c_teflon", name="Тефлон", unit="мл"),
                Consumable(id="c_bitumen", name="Очиститель битума", unit="мл"),
                Consumable(id="c_tire_black", name="Чернитель шин", unit="мл"),
                Consumable(id="c_vac", name="Ресурс пылесоса", unit="сеанс"),
                Consumable(id="c_chem", name="Химия для химчистки", unit="мл"),
                Consumable(id="c_leather", name="Кондиционер для кожи", unit="мл"),
                Consumable(id="c_aroma", name="Ароматизатор", unit="мл"),
                Consumable(id="c_ozone", name="Сеанс озонирования", unit="сеанс"),
                Consumable(id="c_polish", name="Полировальная паста", unit="мл"),
                Consumable(id="c_anticor", name="Антикор", unit="мл"),
            ])
            await session.flush()

            # Расход услуг (только для доп.услуг — s4..s20)
            session.add_all([
                ServiceConsumable(serviceId="s4", consumableId="c_anticor", quantity_per_service=1000),
                ServiceConsumable(serviceId="s5", consumableId="c_engine", quantity_per_service=200),
                ServiceConsumable(serviceId="s6", consumableId="c_glass_polish", quantity_per_service=30),
                ServiceConsumable(serviceId="s7", consumableId="c_antidogd", quantity_per_service=50),
                ServiceConsumable(serviceId="s8", consumableId="c_wax", quantity_per_service=100),
                ServiceConsumable(serviceId="s9", consumableId="c_silant", quantity_per_service=50),
                ServiceConsumable(serviceId="s10", consumableId="c_ceramic", quantity_per_service=30),
                ServiceConsumable(serviceId="s11", consumableId="c_teflon", quantity_per_service=50),
                ServiceConsumable(serviceId="s12", consumableId="c_bitumen", quantity_per_service=100),
                ServiceConsumable(serviceId="s13", consumableId="c_tire_black", quantity_per_service=50),
                ServiceConsumable(serviceId="s14", consumableId="c_vac", quantity_per_service=1),
                ServiceConsumable(serviceId="s15", consumableId="c_chem", quantity_per_service=300),
                ServiceConsumable(serviceId="s16", consumableId="c_leather", quantity_per_service=100),
                ServiceConsumable(serviceId="s17", consumableId="c_aroma", quantity_per_service=10),
                ServiceConsumable(serviceId="s18", consumableId="c_ozone", quantity_per_service=1),
                ServiceConsumable(serviceId="s19", consumableId="c_polish", quantity_per_service=50),
                ServiceConsumable(serviceId="s20", consumableId="c_polish", quantity_per_service=50),
            ])

            # Расход типов мойки
            session.add_all([
                # w1 express — 50мл шампуня
                WashTypeConsumable(washTypeId="w1", consumableId="c_shampoo", quantity_per_service=50),
                # w2 basic — 100мл шампуня
                WashTypeConsumable(washTypeId="w2", consumableId="c_shampoo", quantity_per_service=100),
                # w3 complex — 100мл шампуня + 150мл очистителя салона
                WashTypeConsumable(washTypeId="w3", consumableId="c_shampoo", quantity_per_service=100),
                WashTypeConsumable(washTypeId="w3", consumableId="c_cleaner", quantity_per_service=150),
                # w4 premium — 150мл шампуня + 200мл очистителя салона
                WashTypeConsumable(washTypeId="w4", consumableId="c_shampoo", quantity_per_service=150),
                WashTypeConsumable(washTypeId="w4", consumableId="c_cleaner", quantity_per_service=200),
            ])

            # Включённые доп.услуги для типов мойки
            session.add_all([
                # Комплексная (w3) — пылесосная уборка (s14)
                WashTypeIncludedExtra(washTypeId="w3", extraServiceId="s14"),
                # Премиум (w4) — пылесосная уборка (s14), чернение шин (s13), ароматизация (s17)
                WashTypeIncludedExtra(washTypeId="w4", extraServiceId="s14"),
                WashTypeIncludedExtra(washTypeId="w4", extraServiceId="s13"),
                WashTypeIncludedExtra(washTypeId="w4", extraServiceId="s17"),
            ])
            await session.commit()

        # Promos
        res = await session.execute(select(func.count(Promo.id)))
        if res.scalar() == 0:
            session.add_all([
                Promo(id='promo_1', washTypeId='w3', name='Акция недели: комплекс + ароматизация',
                    description='Комплексная мойка и ароматизация салона по специальной цене недели.',
                    price=1600, discountPercent=0, duration=75, weekendOnly=False, fetchedAt=now),
                Promo(id='promo_2', washTypeId='w2', name='Весенняя акция: мойка + воск',
                    description='Базовая мойка кузова + нанесение защитного воска. Специальная цена до конца месяца.',
                    price=1500, discountPercent=0, duration=50, weekendOnly=False, fetchedAt=now),
                Promo(id='promo_3', washTypeId='w3', name='Выходной пакет: комплексная мойка -20%',
                    description='Комплексная мойка кузова со скидкой 20%. Только по выходным — суббота и воскресенье.',
                    price=0, discountPercent=20, duration=60, weekendOnly=True, fetchedAt=now),
                Promo(id='promo_4', washTypeId='w3', name='Пакет для внедорожников',
                    description='Полный уход для крупных автомобилей: внедорожников и минивэнов. Тщательная мойка колёс и арок.',
                    price=2000, discountPercent=0, duration=80, weekendOnly=False, fetchedAt=now),
            ])
            await session.flush()

            # Включённые в акцию доп.услуги
            session.add_all([
                # promo_1 — ароматизация (s17)
                PromoIncludedExtra(promoId='promo_1', extraServiceId='s17'),
                # promo_2 — нанесение воска (s8)
                PromoIncludedExtra(promoId='promo_2', extraServiceId='s8'),
                # promo_4 — чернение шин (s13), обработка арок (s4)
                PromoIncludedExtra(promoId='promo_4', extraServiceId='s13'),
                PromoIncludedExtra(promoId='promo_4', extraServiceId='s4'),
            ])
            await session.commit()

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
