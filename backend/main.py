from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from database import init_db
from routers import auth, appointments, services, logs, notes, reports, consumables, wash_types

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield

app = FastAPI(title="LanWash API", version="1.0.0", lifespan=lifespan)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)

@app.middleware("http")
async def add_cors_headers(request: Request, call_next):
    if request.method == "OPTIONS":
        return Response(status_code=200, headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
            "Access-Control-Allow-Headers": "*",
        })
    response = await call_next(request)
    response.headers["Access-Control-Allow-Origin"] = "*"
    return response

# Подключаем роутеры БЕЗ дублирующего префикса (он уже есть в роутерах)
app.include_router(auth.router)
app.include_router(appointments.router)
app.include_router(services.router)
app.include_router(logs.router)
app.include_router(notes.router)
app.include_router(reports.router)
app.include_router(consumables.router)
app.include_router(wash_types.router)

@app.get("/debug/routes")
async def get_routes():
    return [{"path": route.path} for route in app.routes]

@app.get("/")
async def root():
    return {"status": "ok", "service": "LanWash API"}

if __name__ == "__main__":
    import uvicorn
    # Добавляем настройку proxy_headers, чтобы ngrok правильно передавал протокол
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True, proxy_headers=True, forwarded_allow_ips="*")
