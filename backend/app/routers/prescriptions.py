from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import current_user
from app.db import get_db
from app.models import (
    Chat,
    Consultation,
    DoctorProfile,
    PatientProfile,
    Prescription,
    PrescriptionPdf,
    User,
)

router = APIRouter(prefix="/api/prescriptions", tags=["prescriptions"])


def _serialize(p: Prescription, doctor_name: str | None = None) -> dict:
    return {
        "id": str(p.id),
        "consultation_id": str(p.consultation_id),
        "items": p.items_json,
        "advice": p.advice,
        "follow_up": p.follow_up,
        "signed_at": p.signed_at.isoformat() if p.signed_at else None,
        "created_at": p.created_at.isoformat(),
        "doctor_name": doctor_name,
    }


@router.get("", response_model=list[dict])
async def list_prescriptions(
    user: Annotated[User, Depends(current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[dict]:
    """Current user's prescriptions. Patients see their signed Rx; doctors see their signed Rx."""
    if user.role == "patient":
        q = (
            select(Prescription, User, DoctorProfile)
            .join(Consultation, Consultation.id == Prescription.consultation_id)
            .join(User, User.id == Consultation.doctor_id)
            .outerjoin(DoctorProfile, DoctorProfile.user_id == Consultation.doctor_id)
            .where(
                Consultation.patient_id == user.id,
                Prescription.signed_at.isnot(None),
            )
            .order_by(Prescription.created_at.desc())
        )
    else:
        q = (
            select(Prescription, User, PatientProfile)
            .join(Consultation, Consultation.id == Prescription.consultation_id)
            .join(User, User.id == Consultation.patient_id)
            .outerjoin(PatientProfile, PatientProfile.user_id == Consultation.patient_id)
            .where(
                Consultation.doctor_id == user.id,
                Prescription.signed_at.isnot(None),
            )
            .order_by(Prescription.created_at.desc())
        )
    r = await db.execute(q)
    out: list[dict] = []
    for p, other_user, profile in r.all():
        if user.role == "patient":
            name = (
                profile.full_name
                if profile and profile.full_name
                else other_user.email
            )
        else:
            name = (
                profile.full_name
                if profile and profile.full_name
                else other_user.email
            )
        out.append(_serialize(p, doctor_name=name))
    return out


@router.get("/{pid}/pdf")
async def get_pdf(
    pid: str,
    user: Annotated[User, Depends(current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    # Auth: must be the patient or the signing doctor on the consultation.
    r = await db.execute(
        select(Prescription, Consultation)
        .join(Consultation, Consultation.id == Prescription.consultation_id)
        .where(Prescription.id == pid)
    )
    row = r.first()
    if not row:
        raise HTTPException(status.HTTP_404_NOT_FOUND)
    p, c = row
    if user.id != c.patient_id and user.id != c.doctor_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN)

    pdf_r = await db.execute(
        select(PrescriptionPdf).where(PrescriptionPdf.prescription_id == pid)
    )
    pdf = pdf_r.scalar_one_or_none()
    if not pdf:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND, detail="PDF not generated"
        )
    return Response(
        content=pdf.pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'inline; filename="rx-{pid[:8]}.pdf"',
        },
    )
