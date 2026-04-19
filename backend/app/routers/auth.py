import random
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import (
    create_access_token,
    current_user,
    hash_password,
    verify_password,
)
from app.db import get_db
from app.models import DoctorProfile, PatientProfile, User

router = APIRouter(prefix="/api", tags=["auth"])


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    role: str  # 'patient' | 'doctor'
    first_name: str | None = None
    last_name: str | None = None
    phone: str | None = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    id: str
    email: str
    role: str
    patient_code: int | None = None
    profile_complete: bool = False


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


def _serialize_user(user: User) -> UserResponse:
    pc = user.patient_profile.patient_code if user.patient_profile else None
    complete = False
    if user.role == "patient" and user.patient_profile:
        complete = bool(user.patient_profile.full_name)
    elif user.role == "doctor" and user.doctor_profile:
        complete = bool(user.doctor_profile.full_name)
    return UserResponse(
        id=str(user.id),
        email=user.email,
        role=user.role,
        patient_code=pc,
        profile_complete=complete,
    )


async def _allocate_patient_code(db: AsyncSession, *, max_attempts: int = 80) -> int:
    for _ in range(max_attempts):
        code = random.randint(1000, 9999)
        found = await db.execute(
            select(PatientProfile).where(PatientProfile.patient_code == code)
        )
        if not found.scalar_one_or_none():
            return code
    raise HTTPException(
        status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Patient code pool exhausted",
    )


async def _fetch_user_with_profiles(db: AsyncSession, user_id) -> User | None:
    result = await db.execute(
        select(User)
        .options(
            selectinload(User.patient_profile),
            selectinload(User.doctor_profile),
        )
        .where(User.id == user_id)
    )
    return result.scalar_one_or_none()


@router.post("/auth/register", response_model=AuthResponse)
async def register(
    body: RegisterRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AuthResponse:
    if body.role not in ("patient", "doctor"):
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail="Role must be 'patient' or 'doctor'",
        )
    if len(body.password) < 6:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail="Password must be at least 6 characters",
        )

    email_lower = body.email.lower()
    existing = await db.execute(select(User).where(User.email == email_lower))
    if existing.scalar_one_or_none():
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    user = User(
        email=email_lower,
        password_hash=hash_password(body.password),
        role=body.role,
    )
    db.add(user)
    await db.flush()

    full_name: str | None = None
    if body.first_name or body.last_name:
        full_name = f"{body.first_name or ''} {body.last_name or ''}".strip()

    if body.role == "patient":
        code = await _allocate_patient_code(db)
        db.add(
            PatientProfile(
                user_id=user.id,
                patient_code=code,
                full_name=full_name,
                phone=body.phone,
            )
        )
    else:
        db.add(
            DoctorProfile(
                user_id=user.id,
                full_name=full_name,
                phone=body.phone,
            )
        )

    await db.commit()

    user = await _fetch_user_with_profiles(db, user.id)
    assert user is not None
    token = create_access_token(str(user.id), user.role)
    return AuthResponse(access_token=token, user=_serialize_user(user))


@router.post("/auth/login", response_model=AuthResponse)
async def login(
    body: LoginRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AuthResponse:
    email_lower = body.email.lower()
    result = await db.execute(
        select(User)
        .options(
            selectinload(User.patient_profile),
            selectinload(User.doctor_profile),
        )
        .where(User.email == email_lower)
    )
    user = result.scalar_one_or_none()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password"
        )
    token = create_access_token(str(user.id), user.role)
    return AuthResponse(access_token=token, user=_serialize_user(user))


@router.get("/me", response_model=UserResponse)
async def me(user: Annotated[User, Depends(current_user)]) -> UserResponse:
    return _serialize_user(user)
