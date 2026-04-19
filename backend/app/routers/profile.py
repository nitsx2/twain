from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import current_user, require_role
from app.db import get_db
from app.models import User

router = APIRouter(prefix="/api/profile", tags=["profile"])


class PatientProfileIn(BaseModel):
    full_name: str
    dob: date | None = None
    sex: str | None = None
    phone: str | None = None
    allergies: str | None = None
    conditions: str | None = None
    current_meds: str | None = None


class PatientProfileOut(BaseModel):
    patient_code: int
    full_name: str
    dob: date | None = None
    sex: str | None = None
    phone: str | None = None
    allergies: str | None = None
    conditions: str | None = None
    current_meds: str | None = None


class DoctorProfileIn(BaseModel):
    full_name: str
    specialty: str | None = None
    registration_no: str | None = None
    clinic_name: str | None = None
    clinic_address: str | None = None
    phone: str | None = None


class DoctorProfileOut(BaseModel):
    full_name: str
    specialty: str | None = None
    registration_no: str | None = None
    clinic_name: str | None = None
    clinic_address: str | None = None
    phone: str | None = None
    has_signature: bool = False


def _patient_out(p) -> PatientProfileOut:
    return PatientProfileOut(
        patient_code=p.patient_code,
        full_name=p.full_name or "",
        dob=p.dob,
        sex=p.sex,
        phone=p.phone,
        allergies=p.allergies,
        conditions=p.conditions,
        current_meds=p.current_meds,
    )


def _doctor_out(d) -> DoctorProfileOut:
    return DoctorProfileOut(
        full_name=d.full_name or "",
        specialty=d.specialty,
        registration_no=d.registration_no,
        clinic_name=d.clinic_name,
        clinic_address=d.clinic_address,
        phone=d.phone,
        has_signature=d.signature_png is not None,
    )


@router.get("/patient", response_model=PatientProfileOut)
async def get_patient_profile(
    user: Annotated[User, Depends(require_role("patient"))],
) -> PatientProfileOut:
    if not user.patient_profile:
        raise HTTPException(status.HTTP_404_NOT_FOUND)
    return _patient_out(user.patient_profile)


@router.put("/patient", response_model=PatientProfileOut)
async def update_patient_profile(
    body: PatientProfileIn,
    user: Annotated[User, Depends(require_role("patient"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> PatientProfileOut:
    if not user.patient_profile:
        raise HTTPException(status.HTTP_404_NOT_FOUND)
    p = user.patient_profile
    p.full_name = body.full_name
    p.dob = body.dob
    p.sex = body.sex
    p.phone = body.phone
    p.allergies = body.allergies
    p.conditions = body.conditions
    p.current_meds = body.current_meds
    await db.commit()
    return _patient_out(p)


@router.get("/doctor", response_model=DoctorProfileOut)
async def get_doctor_profile(
    user: Annotated[User, Depends(require_role("doctor"))],
) -> DoctorProfileOut:
    if not user.doctor_profile:
        raise HTTPException(status.HTTP_404_NOT_FOUND)
    return _doctor_out(user.doctor_profile)


@router.put("/doctor", response_model=DoctorProfileOut)
async def update_doctor_profile(
    body: DoctorProfileIn,
    user: Annotated[User, Depends(require_role("doctor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> DoctorProfileOut:
    if not user.doctor_profile:
        raise HTTPException(status.HTTP_404_NOT_FOUND)
    d = user.doctor_profile
    d.full_name = body.full_name
    d.specialty = body.specialty
    d.registration_no = body.registration_no
    d.clinic_name = body.clinic_name
    d.clinic_address = body.clinic_address
    d.phone = body.phone
    await db.commit()
    return _doctor_out(d)


@router.post("/doctor/signature")
async def upload_signature(
    signature: UploadFile = File(...),
    user: User = Depends(require_role("doctor")),
    db: AsyncSession = Depends(get_db),
) -> dict:
    if not user.doctor_profile:
        raise HTTPException(status.HTTP_404_NOT_FOUND)
    data = await signature.read()
    if not data:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Empty signature")
    if len(data) > 2 * 1024 * 1024:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, detail="Signature too large (>2 MB)"
        )
    user.doctor_profile.signature_png = data
    await db.commit()
    return {"ok": True, "size_bytes": len(data)}
