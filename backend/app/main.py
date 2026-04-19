import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.routers import auth as auth_router
from app.routers import doctor as doctor_router
from app.routers import patient as patient_router
from app.routers import profile as profile_router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
log = logging.getLogger("twain")

settings = get_settings()

app = FastAPI(
    title="Twain AI",
    version="0.1.0",
    description="Medical consultation platform — patient + doctor apps",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["system"])
async def health() -> dict[str, str]:
    return {"status": "ok", "app": "twain", "env": settings.app_env}


app.include_router(auth_router.router)
app.include_router(profile_router.router)
app.include_router(patient_router.router)
app.include_router(doctor_router.router)
