#!/usr/bin/env python3
"""Seed lanwash_test database with fake data for load testing."""

import asyncio
import json
import os
import random
import sys
from datetime import datetime, timedelta

# Ensure backend is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from faker import Faker
from passlib.context import CryptContext
from sqlalchemy import func, select

from database import AsyncSessionLocal, init_db
from models import (
    Appointment,
    LogEntry,
    Review,
    Service,
    Shift,
    User,
    WashType,
)

fake = Faker("ru_RU")
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

TEST_PASSWORD = "testpass123"
TEST_PASSWORD_HASH = pwd_context.hash(TEST_PASSWORD)

STATUSES = ["completed", "scheduled", "cancelled", "in_progress"]
STATUS_WEIGHTS = [70, 20, 5, 5]
BOXES = [0, 1]


def get_test_url():
    base = os.getenv("DATABASE_URL", "postgresql+asyncpg://lanwash_user:password@localhost:5432/lanwash_db")
    if "://" in base:
        scheme, rest = base.split("://", 1)
        if "@" in rest:
            auth_host, _ = rest.rsplit("/", 1)
            return f"{scheme}://{auth_host}/lanwash_test"
    return "postgresql+asyncpg://lanwash_user:password@localhost:5432/lanwash_test"


def random_datetime(start, end):
    delta = end - start
    random_seconds = random.randint(0, int(delta.total_seconds()))
    return start + timedelta(seconds=random_seconds)


def format_dt(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%S")


async def create_users(session):
    """Create test users: clients, washers, admins."""
    users = []

    # 2 admins
    for i in range(2):
        users.append(User(
            username=f"test_admin_{i+1}",
            passwordHash=TEST_PASSWORD_HASH,
            role="admin",
            displayName=fake.name(),
            phone=fake.phone_number(),
            carModel="",
            carNumber="",
            createdAt=format_dt(datetime.now()),
        ))

    # 10 washers
    for i in range(10):
        users.append(User(
            username=f"test_washer_{i+1}",
            passwordHash=TEST_PASSWORD_HASH,
            role="washer",
            displayName=fake.name(),
            phone=fake.phone_number(),
            carModel="",
            carNumber="",
            createdAt=format_dt(datetime.now()),
        ))

    # 50 clients
    car_models = ["Toyota Camry", "BMW X5", "Mercedes C-Class", "Audi A6", "Hyundai Solaris",
                  "Kia Rio", "Volkswagen Polo", "Lada Vesta", "Skoda Octavia", "Nissan Qashqai"]
    for i in range(50):
        users.append(User(
            username=f"test_client_{i+1}",
            passwordHash=TEST_PASSWORD_HASH,
            role="client",
            displayName=fake.name(),
            phone=fake.phone_number(),
            carModel=random.choice(car_models),
            carNumber=fake.license_plate(),
            createdAt=format_dt(datetime.now()),
        ))

    session.add_all(users)
    await session.commit()
    print(f"✅ Created {len(users)} users")
    return users


async def create_appointments(session, users, wash_types, services):
    """Create 500+ appointments across date range."""
    clients = [u for u in users if u.role == "client"]
    washers = [u for u in users if u.role == "washer"]

    now = datetime.now()
    start_date = now - timedelta(days=30)
    end_date = now + timedelta(days=7)

    appointments = []
    for i in range(500):
        client = random.choice(clients)
        status = random.choices(STATUSES, weights=STATUS_WEIGHTS)[0]
        dt = random_datetime(start_date, end_date)

        # Round to nearest 30 min
        minute = (dt.minute // 30) * 30
        dt = dt.replace(minute=minute, second=0, microsecond=0)

        wash_type = random.choice(wash_types)

        # 30% chance to add extra services
        extras = []
        if random.random() < 0.3:
            extras = [s.id for s in random.sample(services, k=random.randint(1, 3))]

        # Price logic
        base_price = wash_type.basePrice
        extra_price = sum(s.price for s in services if s.id in extras)
        promo_discount = random.randint(0, 20)
        original = base_price + extra_price
        paid = int(original * (100 - promo_discount) / 100)

        appointments.append(Appointment(
            id=f"test_appt_{i+1}",
            userId=client.id,
            clientName=client.displayName,
            carModel=client.carModel,
            carNumber=client.carNumber,
            dateTime=format_dt(dt),
            washTypeId=wash_type.id,
            additionalServices=json.dumps(extras),
            status=status,
            notes=fake.sentence(nb_words=6) if random.random() < 0.3 else "",
            ownerUsername=client.username,
            originalPrice=original,
            paidPrice=paid,
            promoPrice=original - paid,
            box_index=random.choice(BOXES),
            assignedWasher=json.dumps([random.choice(washers).username] if washers and status != "scheduled" else []),
        ))

    session.add_all(appointments)
    await session.commit()
    print(f"✅ Created {len(appointments)} appointments")
    return appointments


async def create_shifts(session, washers):
    """Create shifts for washers over last 14 days."""
    now = datetime.now()
    shifts = []
    for day_offset in range(-14, 1):
        date_str = (now + timedelta(days=day_offset)).strftime("%Y-%m-%d")
        for washer in random.sample(washers, k=random.randint(3, 6)):
            start_h = random.randint(8, 14)
            duration = random.choice([4, 6, 8, 10])
            shifts.append(Shift(
                userId=washer.id,
                date=date_str,
                startTime=f"{start_h:02d}:00",
                endTime=f"{(start_h + duration) % 24:02d}:00",
                status="confirmed",
                createdBy="test_admin_1",
                createdAt=format_dt(now),
                updatedAt=format_dt(now),
            ))

    session.add_all(shifts)
    await session.commit()
    print(f"✅ Created {len(shifts)} shifts")
    return shifts


async def create_reviews(session, clients, appointments):
    """Create reviews from clients."""
    completed = [a for a in appointments if a.status == "completed"]
    reviews = []
    for appt in random.sample(completed, k=min(50, len(completed))):
        client = next((u for u in clients if u.id == appt.userId), None)
        if not client:
            continue
        reviews.append(Review(
            userId=client.id,
            userName=client.displayName,
            rating=random.choices([3, 4, 5], weights=[5, 20, 75])[0],
            comment=fake.sentence(nb_words=10) if random.random() < 0.7 else "",
            isPublished=1 if random.random() < 0.8 else 0,
            createdAt=format_dt(datetime.now() - timedelta(days=random.randint(0, 30))),
        ))

    session.add_all(reviews)
    await session.commit()
    print(f"✅ Created {len(reviews)} reviews")
    return reviews


async def create_logs(session, users):
    """Create activity logs."""
    actions = ["login", "create_appointment", "update_appointment", "delete_appointment",
               "view_report", "add_shift", "update_consumable"]
    logs = []
    for _ in range(200):
        user = random.choice(users)
        action = random.choice(actions)
        logs.append(LogEntry(
            username=user.username,
            action=action,
            details=fake.sentence(nb_words=4),
            timestamp=format_dt(datetime.now() - timedelta(days=random.randint(0, 30),
                                                            hours=random.randint(0, 23))),
        ))

    session.add_all(logs)
    await session.commit()
    print(f"✅ Created {len(logs)} logs")
    return logs


async def main():
    os.environ["DATABASE_URL"] = get_test_url()
    print(f"Seeding: {get_test_url()}")

    # Ensure tables exist (init_db creates tables + base data)
    await init_db()

    async with AsyncSessionLocal() as session:
        # Check if already seeded
        res = await session.execute(select(func.count(User.id)).where(User.username.like("test_%")))
        if res.scalar() > 0:
            print("⚠️  Test data already exists. Run clean.py first if you want fresh data.")
            return

        # Fetch base data created by init_db
        wash_types_res = await session.execute(select(WashType))
        wash_types = wash_types_res.scalars().all()

        services_res = await session.execute(select(Service))
        services = services_res.scalars().all()

        print(f"Base data: {len(wash_types)} wash types, {len(services)} services")

        users = await create_users(session)
        appointments = await create_appointments(session, users, wash_types, services)
        washers = [u for u in users if u.role == "washer"]
        await create_shifts(session, washers)
        clients = [u for u in users if u.role == "client"]
        await create_reviews(session, clients, appointments)
        await create_logs(session, users)

    print("🎉 Seed complete!")


if __name__ == "__main__":
    asyncio.run(main())
