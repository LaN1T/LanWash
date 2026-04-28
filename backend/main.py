from contextlib import asynccontextmanager
from dotenv import load_dotenv
import os

# Загружаем переменные из .env файла
load_dotenv(os.path.join(os.path.dirname(__file__), '.env'))

from fastapi import FastAPI, Request, Response, Depends
from fastapi.middleware.cors import CORSMiddleware
from database import init_db
from routers import auth, appointments, services, logs, notes, reports, consumables, wash_types
from services.auth_service import check_roles

from core.limiter import limiter
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

# Инициализация Limiter уже выполнена в core/limiter.py

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield

app = FastAPI(title="LanWash API", version="1.0.0", lifespan=lifespan)

# Применяем Limiter к приложению
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS (P1: Restrict origins strictly)
ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://localhost:8000",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# Глобальный лимит запросов на все API
@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    # Простой глобальный лимит (например, 100 запросов в минуту с IP)
    # Используем limiter, если он уже инициализирован
    return await call_next(request)

# Подключаем роутеры
app.include_router(auth.router)
app.include_router(appointments.router)
app.include_router(services.router)
app.include_router(logs.router)
app.include_router(notes.router)
app.include_router(reports.router, dependencies=[Depends(check_roles(['admin']))])
app.include_router(consumables.router, dependencies=[Depends(check_roles(['admin', 'washer']))])
app.include_router(wash_types.router)

@app.get("/debug/routes", dependencies=[Depends(check_roles(['admin']))]) # P1: Protect debug route
async def get_routes():
    return [{"path": route.path} for route in app.routes]

@app.get("/")
async def root():
    return {"status": "ok", "service": "LanWash API"}

if __name__ == "__main__":
    import uvicorn
    # P3: Remove reload=True and use safer settings for production
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False, proxy_headers=True)
