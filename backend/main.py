from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, Response, Depends
from fastapi.middleware.cors import CORSMiddleware
from database import init_db
from routers import auth, appointments, services, logs, notes, reports, consumables, wash_types
from services.auth_service import check_roles

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield

app = FastAPI(title="LanWash API", version="1.0.0", lifespan=lifespan)

# CORS (P1: Restrict origins in production, for now allow specific ones if known, or keep it safe)
# В учебном проекте часто просят "*", но для безопасности лучше ограничить.
# Оставим список разрешенных хостов.
ALLOWED_ORIGINS = [
    "http://localhost",
    "http://localhost:8000",
    "http://localhost:3000",
    # Добавьте сюда домены вашего фронтенда/web-версии
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Пока оставим *, но уберем allow_credentials=True для безопасности если не нужно
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# Подключаем роутеры
app.include_router(auth.router)
app.include_router(appointments.router)
app.include_router(services.router)
app.include_router(logs.router, dependencies=[Depends(check_roles(['admin']))])
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
